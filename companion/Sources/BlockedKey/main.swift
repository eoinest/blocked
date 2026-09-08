import AppKit
import BlockedCore
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let statusLine = NSMenuItem(title: "Waiting for button", action: nil, keyEquivalent: "")
    private let modeLine = NSMenuItem(title: "Dry run — nothing will be posted", action: nil, keyEquivalent: "")
    private let armItem = NSMenuItem(title: "Arm live reviews…", action: #selector(toggleArmed), keyEquivalent: "")
    private let serial = SerialMonitor()
    private let coordinator = PressCoordinator()
    private var activation = ActivationState()
    private var account: String?
    private var chromeAllowed = false
    private var permissionGeneration = 0
    private var isSigningIn = false
    private var isCheckingAccount = false
    private var buttonStatus = "Plug in your button when ready"
    private var setup: SetupWindow?
    private var deviceCode: String?
    private var testNextPress = false
    private let feedback = FeedbackPanel()
    private lazy var connection = GitHubConnection(executable: { [weak self] in
        ReviewRunner.executable(custom: self?.ghPath ?? "")
    })
    private let loginItem = NSMenuItem(title: "Open at login", action: #selector(toggleLoginItem), keyEquivalent: "")
    private var action: ReviewAction = .requestChanges
    private var body = "blocked"
    private var ghPath = ""
    private var lastResult = "No presses yet."
    private var settings: NSWindow?
    private let actionField = NSPopUpButton()
    private let bodyField = NSTextField()
    private let ghField = NSTextField()
    private let portField = NSTextField()

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let bundleID = Bundle.main.bundleIdentifier,
           let existing = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            existing.activate(options: []); NSApp.terminate(nil); return
        }
        let defaults = UserDefaults.standard
        activation = ActivationState(setupComplete: defaults.bool(forKey: "setupComplete"), enabled: defaults.bool(forKey: "reviewsEnabled"))
        action = ReviewAction(rawValue: defaults.string(forKey: "reviewAction") ?? "") ?? .requestChanges
        body = defaults.string(forKey: "reviewBody") ?? "blocked"
        ghPath = defaults.string(forKey: "ghPath") ?? ""
        serial.manualPath = defaults.string(forKey: "serialPort") ?? ""
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "▣"
        statusItem.button?.setAccessibilityLabel("Blocked")
        statusItem.button?.toolTip = "Blocked — dry run"
        let menu = NSMenu()
        menu.addItem(modeLine); menu.addItem(statusLine); menu.addItem(.separator())
        armItem.target = self; menu.addItem(armItem)
        for (title, selector) in [("Setup & connections…", #selector(showSetup)), ("Settings…", #selector(showSettings)), ("Test next press (no review)", #selector(testButton)), ("Last result…", #selector(showResult)), ("Reconnect button", #selector(reconnect)), ("How to use Blocked…", #selector(showHelp)), ("Quit Blocked", #selector(quit))] {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
            item.target = self; menu.addItem(item)
        }
        loginItem.target = self; menu.insertItem(loginItem, at: 4)
        statusItem.menu = menu
        serial.onStatus = { [weak self] message in
            self?.buttonStatus = message; self?.statusLine.title = message; self?.setup?.updateButton(message)
        }
        serial.onPress = { [weak self] in self?.press() }
        serial.start()
        connection.onChange = { [weak self] state in self?.connectionChanged(state) }
        updateMode()
        if !activation.setupComplete { showSetup() }
        connection.check()
    }

    func applicationWillTerminate(_ notification: Notification) { connection.cancel() }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSetup(); return true
    }

    private func persistActivation() {
        UserDefaults.standard.set(activation.setupComplete, forKey: "setupComplete")
        UserDefaults.standard.set(activation.enabled, forKey: "reviewsEnabled")
        updateMode()
    }

    private func connectionChanged(_ state: GitHubConnection.State) {
        switch state {
        case .checking:
            isCheckingAccount = true
            account = nil; deviceCode = nil; setup?.updateGitHub("Checking your existing GitHub connection…")
        case .connected(let username):
            isCheckingAccount = false; isSigningIn = false
            account = username; deviceCode = nil; setup?.updateGitHub("Connected as @\(username)")
        case .signInRequired(let message), .failed(let message):
            isCheckingAccount = false; isSigningIn = false
            account = nil; deviceCode = nil; setup?.updateGitHub(message)
        case .deviceCode(let code, let url):
            isCheckingAccount = false; isSigningIn = true
            account = nil
            setup?.updateGitHub("Enter this code in GitHub, then approve the connection.", code: code)
            if deviceCode != code { deviceCode = code; NSWorkspace.shared.open(url) }
        }
        setup?.setReady(account != nil && chromeAllowed)
        updateMode()
    }

    @objc private func showSetup() {
        if setup == nil {
            let window = SetupWindow()
            window.onConnectGitHub = { [weak self] in self?.isSigningIn = true; self?.connection.signIn() }
            window.onCancelSignIn = { [weak self] in self?.isSigningIn = false; self?.connection.cancel(); self?.connection.check() }
            window.onAllowChrome = { [weak self] in self?.checkChrome(request: true) }
            window.onEnable = { [weak self] launchAtLogin in self?.finishSetup(launchAtLogin: launchAtLogin) }
            setup = window
        }
        setup?.updateAction(action.title, body: body)
        setup?.showMessage("")
        if UserDefaults.standard.object(forKey: "openAtLoginRequested") != nil {
            setup?.updateLaunchAtLogin(SMAppService.mainApp.status == .enabled || SMAppService.mainApp.status == .requiresApproval)
        }
        setup?.updateButton(buttonStatus)
        if let account { setup?.updateGitHub("Connected as @\(account)") }
        setup?.setReady(account != nil && chromeAllowed)
        setup?.showWindow(nil); NSApp.activate(ignoringOtherApps: true)
        checkChrome(request: false)
    }

    private func checkChrome(request: Bool) {
        permissionGeneration += 1
        let generation = permissionGeneration
        chromeAllowed = false; setup?.setReady(false)
        ChromePermission.check(request: request) { [weak self] allowed, message in
            guard let self, self.permissionGeneration == generation else { return }
            self.chromeAllowed = allowed; self.setup?.updateChrome(message, allowed: allowed)
            self.setup?.setReady(self.account != nil && allowed)
        }
    }

    private func finishSetup(launchAtLogin: Bool) {
        setup?.showMessage("")
        guard activation.enable(accountConnected: account != nil, chromeAllowed: chromeAllowed) else { return }
        persistActivation()
        UserDefaults.standard.set(launchAtLogin, forKey: "openAtLoginRequested")
        do {
            if launchAtLogin, SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            else if !launchAtLogin, [.enabled, .requiresApproval].contains(SMAppService.mainApp.status) { try SMAppService.mainApp.unregister() }
            updateMode()
            if SMAppService.mainApp.status == .requiresApproval {
                setup?.showMessage("Your button is enabled. Approve Blocked in System Settings → General → Login Items to have it start automatically.")
                return
            }
            setup?.close()
            feedback.show("Ready. Open a pull request in Chrome and press your button.", error: false)
        } catch {
            setup?.showMessage("Your button is enabled, but automatic launch needs attention. Move Blocked to Applications and check Login Items in System Settings. \(error.localizedDescription)")
        }
    }

    @objc private func toggleLoginItem() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
            UserDefaults.standard.set(SMAppService.mainApp.status != .notRegistered, forKey: "openAtLoginRequested")
            if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        } catch { feedback.show("Could not change Open at login. \(error.localizedDescription)", error: true) }
        updateMode()
    }

    private func updateMode() {
        let description: String
        if !activation.setupComplete { description = "Finish setup to enable your button" }
        else if !activation.enabled { description = "Paused" }
        else if let account { description = "Enabled · @\(account) · \(action.title)" }
        else { description = "GitHub connection needs attention" }
        modeLine.title = description
        armItem.title = activation.enabled ? "Pause button" : "Enable button…"
        statusItem.button?.title = activation.enabled && account != nil ? "▣" : "▣ ‖"
        statusItem.button?.toolTip = "Blocked — \(description)"
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }
    @objc private func toggleArmed() {
        if activation.enabled { activation.pause(); persistActivation() }
        else { showSetup(); if !isSigningIn && !isCheckingAccount { connection.check() } }
    }
    @objc private func showResult() {
        let alert = NSAlert(); alert.messageText = "Last result"; alert.informativeText = lastResult
        NSApp.activate(ignoringOtherApps: true); alert.runModal()
    }
    @objc private func reconnect() { serial.reconnect() }
    @objc private func testButton() {
        testNextPress = true
        feedback.show("The next press will only show the detected PR. Nothing will be posted.", error: false)
    }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func showHelp() {
        let alert = NSAlert()
        alert.messageText = "Your button is ready when Blocked is running"
        alert.informativeText = "Plug in your button with a USB data cable, focus a GitHub pull request in Chrome, then press once. Unplugging and reconnecting works automatically—no reset button or port selection needed.\n\nKeep Open at login enabled so Blocked starts with your Mac. If you quit Blocked, reopen it from Applications.\n\nEach press posts your configured review. The same PR has a 10-second cooldown. Pressing again does not undo a review; dismiss it in GitHub to remove a test block.\n\nSetup & connections shows your GitHub account, Chrome permission, and button connection. Test next press checks the detected PR without posting."
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func showSettings() {
        if let settings { settings.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 340), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Blocked Settings"; window.isReleasedWhenClosed = false
        func label(_ text: String, y: CGFloat) {
            let label = NSTextField(labelWithString: text); label.frame = NSRect(x: 24, y: y, width: 470, height: 20)
            window.contentView?.addSubview(label)
        }
        label("Review action", y: 302)
        actionField.frame = NSRect(x: 24, y: 268, width: 472, height: 28)
        actionField.addItems(withTitles: ReviewAction.allCases.map(\.title))
        actionField.selectItem(withTitle: action.title)
        label("Review message", y: 239)
        bodyField.frame = NSRect(x: 24, y: 209, width: 472, height: 26); bodyField.stringValue = body
        label("Advanced: GitHub helper override (normally leave blank)", y: 181)
        ghField.frame = NSRect(x: 24, y: 151, width: 472, height: 26); ghField.stringValue = ghPath
        label("Advanced: USB port override (normally leave blank)", y: 123)
        portField.frame = NSRect(x: 24, y: 93, width: 472, height: 26); portField.stringValue = serial.manualPath
        label("Saving changes asks you to enable the new action once.", y: 59)
        let save = NSButton(title: "Save", target: self, action: #selector(saveSettings))
        save.frame = NSRect(x: 400, y: 18, width: 96, height: 30); save.bezelStyle = .rounded
        for view in [actionField, bodyField, ghField, portField, save] as [NSView] { window.contentView?.addSubview(view) }
        settings = window; window.center(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }
    @objc private func saveSettings() {
        guard !bodyField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              bodyField.stringValue.utf8.count <= 4000 else {
            lastResult = "Use a nonempty message up to 4,000 bytes."; showResult(); return
        }
        action = ReviewAction.allCases[actionField.indexOfSelectedItem]
        body = bodyField.stringValue; ghPath = ghField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        serial.manualPath = portField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let defaults = UserDefaults.standard
        defaults.set(action.rawValue, forKey: "reviewAction"); defaults.set(body, forKey: "reviewBody")
        defaults.set(ghPath, forKey: "ghPath"); defaults.set(serial.manualPath, forKey: "serialPort")
        activation.configurationChanged(); persistActivation(); serial.reconnect(); settings?.close()
        showSetup(); connection.check()
    }

    private func report(_ message: String, result: String) {
        lastResult = message; statusLine.title = String(message.prefix(90)); serial.result(result)
        feedback.show(message, error: result == "ERROR")
    }
    private func press() {
        if testNextPress {
            testNextPress = false
            coordinator.press(armed: false, action: action, body: body, ghPath: ghPath,
                              report: { [weak self] message, result in self?.report(message, result: result) })
            return
        }
        guard activation.setupComplete else { showSetup(); return }
        guard activation.enabled else { feedback.show("Blocked is paused. Enable it from the menu bar.", error: false); return }
        guard account != nil else {
            showSetup()
            if !isSigningIn && !isCheckingAccount { connection.check() }
            return
        }
        coordinator.press(armed: true, action: action, body: body, ghPath: ghPath,
                          submitting: { [weak self] in self?.statusLine.title = $0 },
                          report: { [weak self] message, result in self?.report(message, result: result) })
    }

}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
