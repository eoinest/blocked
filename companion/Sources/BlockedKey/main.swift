import AppKit
import BlockedCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let statusLine = NSMenuItem(title: "Waiting for button", action: nil, keyEquivalent: "")
    private let modeLine = NSMenuItem(title: "Dry run — nothing will be posted", action: nil, keyEquivalent: "")
    private let armItem = NSMenuItem(title: "Arm live reviews…", action: #selector(toggleArmed), keyEquivalent: "")
    private let serial = SerialMonitor()
    private var gate = PressGate()
    private var armed = false
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
        let defaults = UserDefaults.standard
        action = ReviewAction(rawValue: defaults.string(forKey: "reviewAction") ?? "") ?? .requestChanges
        body = defaults.string(forKey: "reviewBody") ?? "blocked"
        ghPath = defaults.string(forKey: "ghPath") ?? ""
        serial.manualPath = defaults.string(forKey: "serialPort") ?? ""
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "▣"
        statusItem.button?.toolTip = "Blocked — dry run"
        let menu = NSMenu()
        menu.addItem(modeLine); menu.addItem(statusLine); menu.addItem(.separator())
        armItem.target = self; menu.addItem(armItem)
        for (title, selector) in [("Settings…", #selector(showSettings)), ("Last result…", #selector(showResult)), ("Reconnect button", #selector(reconnect)), ("Quit Blocked", #selector(quit))] {
            let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
            item.target = self; menu.addItem(item)
        }
        statusItem.menu = menu
        serial.onStatus = { [weak self] message in self?.statusLine.title = message }
        serial.onPress = { [weak self] in self?.press() }
        serial.start()
    }

    private func updateMode() {
        modeLine.title = armed ? "LIVE: \(action.title)" : "Dry run — nothing will be posted"
        armItem.title = armed ? "Disarm live reviews" : "Arm live reviews…"
        statusItem.button?.title = armed ? "▣ LIVE" : "▣"
        statusItem.button?.toolTip = "Blocked — \(armed ? "live reviews" : "dry run")"
    }
    @objc private func toggleArmed() {
        if armed { armed = false; updateMode(); return }
        let alert = NSAlert()
        alert.messageText = "Arm live GitHub reviews?"
        alert.informativeText = "A button press will \(action.title.lowercased()) on the pull request in your focused Google Chrome tab using gh’s signed-in account.\n\nMessage:\n\(body)\n\nThe app returns to dry run when restarted."
        alert.addButton(withTitle: "Arm live reviews"); alert.addButton(withTitle: "Cancel")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn { armed = true; updateMode() }
    }
    @objc private func showResult() {
        let alert = NSAlert(); alert.messageText = "Last result"; alert.informativeText = lastResult
        NSApp.activate(ignoringOtherApps: true); alert.runModal()
    }
    @objc private func reconnect() { serial.reconnect() }
    @objc private func quit() { NSApp.terminate(nil) }

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
        label("gh executable (blank = Homebrew default)", y: 181)
        ghField.frame = NSRect(x: 24, y: 151, width: 472, height: 26); ghField.stringValue = ghPath
        label("Serial port (blank = discover Blocked Key USB product)", y: 123)
        portField.frame = NSRect(x: 24, y: 93, width: 472, height: 26); portField.stringValue = serial.manualPath
        label("Saving settings returns to dry run.", y: 59)
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
        armed = false; updateMode(); serial.reconnect(); settings?.close()
    }

    private func report(_ message: String, result: String) {
        lastResult = message; statusLine.title = String(message.prefix(90)); serial.result(result)
        if result == "ERROR" { NSSound.beep() }
    }
    private func press() {
        let started = ProcessInfo.processInfo.systemUptime
        guard gate.begin(now: started) else { return }
        do {
            let first = try ChromeTarget.read()
            let second = try ChromeTarget.read()
            guard first == second, ProcessInfo.processInfo.systemUptime - started < 1 else {
                throw BlockedError.message("Focus changed or Chrome access took too long. Press again.")
            }
            let command = ReviewCommand(pr: first.pr, action: action, body: body)
            if !armed {
                report("DRY RUN: \(action.title)\n\(first.pr.url)\n\n\(body)", result: "DRY_RUN")
                gate.finish(); return
            }
            guard let executable = ReviewRunner.executable(custom: ghPath) else {
                throw BlockedError.message("gh was not found. Install GitHub CLI and run gh auth login in Terminal, or set its absolute path in Settings.")
            }
            guard gate.reserveSubmission(first.pr, now: started) else {
                throw BlockedError.message("Already attempted this PR in the last minute. Check it before trying again.")
            }
            // No async work between the final focus read and launching gh.
            let submittedAction = action
            let submittedBody = body
            statusLine.title = "Submitting \(first.pr.owner)/\(first.pr.repository)#\(first.pr.number)…"
            try ReviewRunner.start(executable: executable, arguments: command.arguments) { [weak self] outcome in
                guard let self else { return }
                self.gate.finish()
                switch outcome {
                case .success: self.report("Posted \(submittedAction.title.lowercased())\n\(first.pr.url)\n\n\(submittedBody)", result: "OK")
                case .failure(let error): self.report(error.localizedDescription, result: "ERROR")
                }
            }
        } catch { gate.finish(); report(error.localizedDescription, result: "ERROR") }
    }
}

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
