import AppKit
import ApplicationServices
import ServiceManagement
import KeyCommandCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = SettingsStore()
    private let hub = DeviceHub(discover: USBDiscovery.paths)
    private var gate = ActionGate()
    private var runners: [String: CommandRunner] = [:]
    private var pendingShortcuts: [String: DispatchWorkItem] = [:]
    private var counts: [String: Int] = [:]
    private var results: [String: String] = [:]
    private var timer: Timer?
    private let origin = ContinuousClock.now
    private var item: NSStatusItem!
    private var window: NSWindow!
    private var selectedID: String?
    private let device = NSPopUpButton()
    private let deviceStatus = NSTextField(labelWithString: "Plug in a Key Command button to begin.")
    private let nickname = NSTextField()
    private let enabled = NSButton(checkboxWithTitle: "Enabled", target: nil, action: nil)
    private let diagnostics = NSButton(checkboxWithTitle: "Count presses only · no action", target: nil, action: nil)
    private let mode = NSSegmentedControl(labels: ["Shell command", "Keyboard shortcut"], trackingMode: .selectOne, target: nil, action: nil)
    private let script = NSTextView()
    private let scriptScroll = NSScrollView()
    private let cwd = NSTextField()
    private let cwdLabel = NSTextField(labelWithString: "Working directory")
    private let timeout = NSTextField()
    private let timeoutLabel = NSTextField(labelWithString: "Stop command after (seconds)")
    private let modeHint = NSTextField(wrappingLabelWithString: "")
    private let recorder = ShortcutRecorder()
    private let clearShortcut = NSButton(title: "Clear shortcut", target: nil, action: nil)
    private let access = NSButton(title: "Allow keyboard shortcuts…", target: nil, action: nil)
    private let output = NSTextView()
    private let resultLabel = NSTextField(labelWithString: "No button selected")
    private let login = NSButton(checkboxWithTitle: "Open at login", target: nil, action: nil)
    private let reopenNotification = Notification.Name("com.eoinest.keycommand.showWindow")

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let bundleID = Bundle.main.bundleIdentifier,
           let existing = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            DistributedNotificationCenter.default().postNotificationName(reopenNotification, object: bundleID, userInfo: nil, deliverImmediately: true)
            existing.activate(options: []); NSApp.terminate(nil); return
        }
        NSApp.setActivationPolicy(.accessory)
        buildMainMenu()
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "command.square", accessibilityDescription: "Key Command")
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Key Command…", action: #selector(showWindow), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Reconnect buttons", action: #selector(reconnect), keyEquivalent: "").target = self
        menu.addItem(withTitle: "How to use Key Command", action: #selector(help), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Key Command", action: #selector(quit), keyEquivalent: "q").target = self
        item.menu = menu
        buildWindow()
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(showWindow), name: reopenNotification, object: Bundle.main.bundleIdentifier)
        hub.onChange = { [weak self] in self?.devicesChanged() }
        hub.onPress = { [weak self] id in self?.physicalPress(id) }
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(suspendShortcuts), name: NSWorkspace.willSleepNotification, object: nil)
        NSWorkspace.shared.notificationCenter.addObserver(self, selector: #selector(suspendShortcuts), name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self else { return }
            let elapsed = origin.duration(to: .now).components
            hub.poll(now: Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18)
        }
        RunLoop.main.add(timer!, forMode: .common)
        refreshDevices()
        if !UserDefaults.standard.bool(forKey: "hasOpened") { showWindow(); UserDefaults.standard.set(true, forKey: "hasOpened") }
    }

    func applicationWillTerminate(_ notification: Notification) { timer?.invalidate(); hub.stop(); runners.values.forEach { $0.cancel() }; pendingShortcuts.values.forEach { $0.cancel() } }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showWindow(); return true }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        pendingShortcuts.values.forEach { $0.cancel() }
        guard !runners.isEmpty else { return .terminateNow }
        runners.values.forEach { $0.cancel() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.runners.values.forEach { $0.cancel(force: true) }
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
    @objc private func quit() { NSApp.terminate(nil) }
    @objc private func showWindow() { refreshLogin(); window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    @objc private func reconnect() { hub.reconnect() }
    @objc private func help() {
        let alert = NSAlert(); alert.messageText = "One button, your action"
        alert.informativeText = "Plug in a button with Key Command firmware. Select it, choose a command or record a shortcut, then Save configuration and enable it. Each button keeps its own settings.\n\nCommands run in zsh with your Mac account’s permissions. Shortcuts go to the app you are using. Test shortcut gives you three seconds to switch apps. Count presses only checks the physical button without running anything.\n\nKeep Key Command running in the menu bar; Open at login starts it automatically."
        alert.runModal()
    }

    private func label(_ text: String, _ frame: NSRect, size: CGFloat = 13, bold: Bool = false) {
        let field = NSTextField(labelWithString: text); field.frame = frame
        field.font = .systemFont(ofSize: size, weight: bold ? .semibold : .regular)
        window.contentView!.addSubview(field)
    }
    private func add(_ view: NSView, _ frame: NSRect) { view.frame = frame; window.contentView!.addSubview(view) }
    private func button(_ title: String, _ action: Selector, _ frame: NSRect) {
        let button = NSButton(title: title, target: self, action: action); button.bezelStyle = .rounded; add(button, frame)
    }
    private func buildMainMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem(); let appMenu = NSMenu(title: "Key Command")
        appMenu.addItem(withTitle: "About Key Command", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(withTitle: "Open Key Command…", action: #selector(showWindow), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide Key Command", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Key Command", action: #selector(quit), keyEquivalent: "q").target = self
        appItem.submenu = appMenu; main.addItem(appItem)

        let editItem = NSMenuItem(); let editMenu = NSMenu(title: "Edit")
        // A nil target routes editing to the current first responder, including
        // the shared NSTextField editor and the script's own NSTextView.
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu; main.addItem(editItem)
        let windowItem = NSMenuItem(); let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowItem.submenu = windowMenu; main.addItem(windowItem)
        NSApp.mainMenu = main; NSApp.windowsMenu = windowMenu
    }
    private func sizeTextView(_ text: NSTextView, in scroll: NSScrollView) {
        text.frame = NSRect(origin: .zero, size: scroll.contentSize)
        text.minSize = NSSize(width: 0, height: scroll.contentSize.height)
        text.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        text.isVerticallyResizable = true; text.isHorizontallyResizable = false
        text.autoresizingMask = [.width]
        text.textContainer?.containerSize = NSSize(width: scroll.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        text.textContainer?.widthTracksTextView = true
    }
    private func buildWindow() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 740, height: 748), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Key Command"; window.isReleasedWhenClosed = false; window.center()
        label("Key Command", NSRect(x: 26, y: 692, width: 600, height: 34), size: 27, bold: true)
        label("A physical button for the commands and shortcuts you use.", NSRect(x: 27, y: 664, width: 680, height: 22))
        add(device, NSRect(x: 24, y: 621, width: 690, height: 30)); device.target = self; device.action = #selector(selectDevice)
        add(deviceStatus, NSRect(x: 27, y: 595, width: 680, height: 22)); deviceStatus.textColor = .secondaryLabelColor
        label("Name", NSRect(x: 27, y: 558, width: 50, height: 22))
        add(nickname, NSRect(x: 82, y: 555, width: 630, height: 26))
        add(enabled, NSRect(x: 27, y: 516, width: 130, height: 26)); enabled.target = self; enabled.action = #selector(toggleEnabled)
        add(diagnostics, NSRect(x: 170, y: 516, width: 410, height: 26)); diagnostics.target = self; diagnostics.action = #selector(toggleDiagnostics)
        add(mode, NSRect(x: 24, y: 474, width: 690, height: 30)); mode.selectedSegment = 0; mode.target = self; mode.action = #selector(modeChanged)
        add(modeHint, NSRect(x: 27, y: 422, width: 683, height: 44)); modeHint.textColor = .secondaryLabelColor
        script.isRichText = false; script.allowsUndo = true; script.isAutomaticQuoteSubstitutionEnabled = false; script.isAutomaticDashSubstitutionEnabled = false
        script.isAutomaticTextReplacementEnabled = false; script.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        script.textContainerInset = NSSize(width: 10, height: 10)
        scriptScroll.documentView = script; scriptScroll.hasVerticalScroller = true; scriptScroll.borderType = .bezelBorder
        add(scriptScroll, NSRect(x: 27, y: 272, width: 686, height: 146))
        sizeTextView(script, in: scriptScroll)
        add(cwdLabel, NSRect(x: 27, y: 235, width: 145, height: 22)); add(cwd, NSRect(x: 175, y: 232, width: 538, height: 26))
        add(timeoutLabel, NSRect(x: 27, y: 197, width: 230, height: 22)); add(timeout, NSRect(x: 269, y: 194, width: 90, height: 26))
        add(recorder, NSRect(x: 27, y: 311, width: 686, height: 103))
        add(clearShortcut, NSRect(x: 27, y: 270, width: 160, height: 30)); clearShortcut.target = self; clearShortcut.action = #selector(clearRecordedShortcut)
        add(access, NSRect(x: 27, y: 222, width: 280, height: 32)); access.target = self; access.action = #selector(requestAccessibility)
        button("Save configuration", #selector(saveConfiguration), NSRect(x: 22, y: 151, width: 176, height: 34))
        button("Test action", #selector(testAction), NSRect(x: 202, y: 151, width: 128, height: 34))
        button("Cancel running action", #selector(cancelSelected), NSRect(x: 340, y: 151, width: 190, height: 34))
        add(resultLabel, NSRect(x: 27, y: 124, width: 686, height: 22)); resultLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        output.isEditable = false; output.isRichText = false; output.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        let resultScroll = NSScrollView(); resultScroll.documentView = output; resultScroll.hasVerticalScroller = true; resultScroll.borderType = .bezelBorder
        add(resultScroll, NSRect(x: 27, y: 36, width: 686, height: 84))
        sizeTextView(output, in: resultScroll)
        add(login, NSRect(x: 27, y: 5, width: 250, height: 26)); login.target = self; login.action = #selector(toggleLogin)
        modeChanged()
    }

    private func devicesChanged() {
        for id in hub.onlineIDs where store.bindings[id] == nil { try? store.save(Binding(deviceID: id)) }
        refreshDevices()
    }
    private func refreshDevices() {
        let previous = selectedID
        let ids = Set(store.bindings.keys).union(hub.onlineIDs).union(hub.conflictedIDs).sorted()
        device.removeAllItems()
        for id in ids {
            let binding = store.binding(for: id)
            let status = hub.conflictedIDs.contains(id) ? "ID conflict" : hub.onlineIDs.contains(id) ? "Connected" : "Offline"
            device.addItem(withTitle: "\(binding.nickname)   ·   \(status)   ·   \(id)")
            device.lastItem?.representedObject = id
        }
        if ids.isEmpty { device.addItem(withTitle: "Connect a Key Command button…"); selectedID = nil }
        else {
            selectedID = previous.flatMap { ids.contains($0) ? $0 : nil } ?? ids.first
            if let id = selectedID, let index = ids.firstIndex(of: id) { device.selectItem(at: index) }
        }
        if previous != selectedID { loadSelection() }
        updateStatus()
    }
    @objc private func selectDevice() { selectedID = device.selectedItem?.representedObject as? String; loadSelection(); updateStatus() }
    private func loadSelection() {
        guard let id = selectedID else { return }
        let binding = store.binding(for: id)
        nickname.stringValue = binding.nickname; script.string = binding.command; cwd.stringValue = binding.workingDirectory
        timeout.doubleValue = binding.timeout; mode.selectedSegment = binding.kind == .command ? 0 : 1
        recorder.shortcut = binding.shortcut; enabled.state = binding.enabled ? .on : .off
        diagnostics.state = binding.diagnosticsOnly ? .on : .off; updateMode()
    }
    private func updateStatus() {
        guard let id = selectedID else { deviceStatus.stringValue = hub.portCount > 0 ? "USB detected. Waiting for the Key Command firmware handshake…" : "Plug in a Key Command button to begin."; return }
        let status = hub.conflictedIDs.contains(id) ? "Duplicate ID — actions blocked" : hub.onlineIDs.contains(id) ? "Connected" : "Offline — reconnects automatically"
        deviceStatus.stringValue = "\(status)   ·   \(counts[id] ?? 0) physical presses this session"
        resultLabel.stringValue = gate.isRunning(id) ? "Action running · new presses are ignored" : "Last result"
        output.string = results[id] ?? "No action yet. Save a configuration, then use Test action or press your button."
    }
    @objc private func modeChanged() { updateMode() }
    private func updateMode() {
        let command = mode.selectedSegment == 0
        [scriptScroll, cwd, cwdLabel, timeout, timeoutLabel].forEach { $0.isHidden = !command }
        [recorder, clearShortcut, access].forEach { $0.isHidden = command }
        modeHint.stringValue = command ? "Runs your exact script in /bin/zsh -lc. Your login shell configuration loads; no Terminal window opens. Save to apply edits." : "Click the box and press a shortcut. Physical presses send it to your focused app. Test gives you 3 seconds to switch apps. Save to apply edits."
    }
    @objc private func clearRecordedShortcut() { recorder.shortcut = nil }
    private func draft() throws -> Binding {
        guard let id = selectedID else { throw CommandError("Connect and select a button first.") }
        var binding = store.binding(for: id)
        binding.nickname = nickname.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if binding.nickname.isEmpty { binding.nickname = "Button \(id.suffix(4))" }
        binding.kind = mode.selectedSegment == 0 ? .command : .shortcut; binding.command = script.string
        binding.workingDirectory = NSString(string: cwd.stringValue).expandingTildeInPath; binding.timeout = timeout.doubleValue
        binding.shortcut = recorder.shortcut; binding.enabled = enabled.state == .on; binding.diagnosticsOnly = diagnostics.state == .on
        return binding
    }
    @discardableResult private func saveDraft() -> Binding? {
        do {
            let binding = try draft(); try store.save(binding)
            cancel(binding.deviceID)
            results[binding.deviceID] = binding.enabled ? "Saved and enabled." : "Saved. Enable this button when ready."
            refreshDevices(); updateStatus(); return binding
        } catch { showError(error.localizedDescription); return nil }
    }
    @objc private func saveConfiguration() { _ = saveDraft() }
    @objc private func toggleEnabled() {
        if enabled.state == .off, let id = selectedID {
            var binding = store.binding(for: id); binding.enabled = false; try? store.save(binding); cancel(id)
            results[id] = "Disabled. Physical presses are counted without running an action."; updateStatus()
        } else if saveDraft() == nil { enabled.state = .off }
    }
    @objc private func toggleDiagnostics() {
        guard let id = selectedID else { return }
        var binding = store.binding(for: id); binding.diagnosticsOnly = diagnostics.state == .on
        try? store.save(binding)
        if binding.diagnosticsOnly { cancel(id) }
        results[id] = binding.diagnosticsOnly ? "Diagnostics only: press the physical button. No action will run." : "Diagnostics off. Saved enable state applies."
        updateStatus()
    }
    private func physicalPress(_ id: String) {
        counts[id, default: 0] += 1
        let binding = store.binding(for: id)
        if !binding.enabled || binding.diagnosticsOnly { results[id] = "Physical press detected · no action (\(binding.diagnosticsOnly ? "diagnostics" : "disabled"))." }
        else { run(binding, test: false) }
        updateStatus()
    }
    @objc private func testAction() {
        guard let binding = saveDraft() else { return }
        if let error = binding.validationError { showError(error); return }
        if binding.diagnosticsOnly { showError("Turn off Count presses only before testing an action, or press the physical button to check its counter."); return }
        run(binding, test: true)
    }
    private func run(_ binding: Binding, test: Bool) {
        let id = binding.deviceID
        guard gate.begin(binding, now: ProcessInfo.processInfo.systemUptime, test: test) else { return }
        if binding.kind == .command {
            let runner = CommandRunner(); runners[id] = runner; results[id] = "Running command…"
            runner.start(command: binding.command, directory: binding.workingDirectory, timeout: binding.timeout) { [weak self] result in
                guard let self else { return }
                runners.removeValue(forKey: id); gate.finish(id)
                results[id] = result.summary + (result.truncated ? " · output limited to 64 KiB" : "") + "\n" + result.output
                updateStatus()
            }
        } else if test {
            results[id] = "Switch to the destination app. Sending shortcut in 3 seconds…"
            let deadline = ContinuousClock.now.advanced(by: .milliseconds(3500))
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                pendingShortcuts.removeValue(forKey: id)
                guard ContinuousClock.now <= deadline else {
                    gate.finish(id); results[id] = "Shortcut test expired after a pause. Test again when ready."; updateStatus(); return
                }
                sendShortcut(binding)
            }
            pendingShortcuts[id] = work; DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: work)
        } else { sendShortcut(binding) }
        updateStatus()
    }
    private func sendShortcut(_ binding: Binding) {
        defer { gate.finish(binding.deviceID); updateStatus() }
        guard let shortcut = binding.shortcut, shortcut.isValid else { results[binding.deviceID] = "No valid shortcut recorded."; return }
        let focused = NSWorkspace.shared.frontmostApplication
        if let reason = shortcut.blockReason(trusted: AXIsProcessTrusted(), targetPID: focused?.processIdentifier,
            ownPID: ProcessInfo.processInfo.processIdentifier,
            heldModifiers: CGEventSource.flagsState(.combinedSessionState).rawValue,
            keyHeld: CGEventSource.keyState(.combinedSessionState, key: shortcut.keyCode)) {
            results[binding.deviceID] = reason; return
        }
        guard let frontmost = focused else { return }
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: shortcut.keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: shortcut.keyCode, keyDown: false),
              NSWorkspace.shared.frontmostApplication?.processIdentifier == frontmost.processIdentifier else {
            results[binding.deviceID] = "Focus changed before sending the shortcut. Try again."; return
        }
        down.flags = CGEventFlags(rawValue: shortcut.modifiers); up.flags = CGEventFlags(rawValue: shortcut.modifiers)
        down.postToPid(frontmost.processIdentifier); up.postToPid(frontmost.processIdentifier)
        results[binding.deviceID] = "Sent \(shortcut.label) to \(frontmost.localizedName ?? "the focused app")."
    }
    private func cancel(_ id: String) {
        runners[id]?.cancel()
        if let pending = pendingShortcuts.removeValue(forKey: id) { pending.cancel(); gate.finish(id) }
    }
    @objc private func suspendShortcuts() {
        for id in Array(pendingShortcuts.keys) { cancel(id); results[id] = "Shortcut test cancelled because the Mac paused." }
        hub.reconnect(); updateStatus()
    }
    @objc private func cancelSelected() {
        guard let id = selectedID else { return }
        guard gate.isRunning(id) else { results[id] = "No action is running."; updateStatus(); return }
        let shortcutPending = pendingShortcuts[id] != nil
        cancel(id); results[id] = shortcutPending ? "Cancelled." : "Cancelling…"; updateStatus()
    }
    @objc private func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
    private func refreshLogin() { login.state = SMAppService.mainApp.status == .enabled ? .on : .off }
    @objc private func toggleLogin() {
        do {
            if login.state == .on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            if SMAppService.mainApp.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
        } catch { showError("Could not change Open at login: \(error.localizedDescription). Install Key Command in Applications first.") }
        refreshLogin()
    }
    private func showError(_ message: String) { let alert = NSAlert(); alert.messageText = "Key Command"; alert.informativeText = message; alert.runModal() }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
