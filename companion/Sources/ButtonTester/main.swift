import AppKit
import SwiftUI
import ButtonTestCore

final class TesterModel: ObservableObject {
    @Published var status = "Waiting for USB — plug in your flashed ESP32."
    @Published var connected = false
    @Published var isDown: Bool?
    @Published var count = 0
    @Published var history: [String] = []
    @Published var changedAt = Date()
    private let serial = TesterSerial()
    private let timestamp: DateFormatter = {
        let formatter = DateFormatter(); formatter.dateFormat = "HH:mm:ss.SSS"; return formatter
    }()
    func start() {
        serial.onStatus = { [weak self] status, connected in
            guard let self else { return }
            self.status = status; self.connected = connected
            if !connected { self.isDown = nil }
        }
        serial.onEvent = { [weak self] event in
            guard let self else { return }
            switch event {
            case .connected: self.isDown = nil
            case let .state(down, newPress):
                if newPress { self.count += 1 }
                if self.isDown != down {
                    self.changedAt = Date()
                    let label = down ? (newPress ? "PRESS #\(self.count)" : "HELD ON CONNECT") : "RELEASED"
                    self.history.insert("\(self.timestamp.string(from: Date()))   \(label)", at: 0)
                    self.history = Array(self.history.prefix(6))
                }
                self.isDown = down
            }
        }
        serial.start()
    }
    func resetCount() { count = 0; history.removeAll() }
    func reconnect() { isDown = nil; connected = false; serial.reconnect() }
    func stop() { serial.stop() }
}

struct TesterView: View {
    @ObservedObject var model: TesterModel
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Button test").font(.system(size: 29, weight: .semibold))
                Text("Check your soldering. No GitHub actions.").foregroundColor(.secondary)
            }
            HStack(spacing: 9) {
                Circle().fill(model.connected ? Color.green : Color.orange).frame(width: 9, height: 9)
                Text(model.status).font(.system(size: 13)).fixedSize(horizontal: false, vertical: true)
            }.frame(minHeight: 34, alignment: .leading)
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(model.isDown == true ? Color.green.opacity(0.22) : Color.secondary.opacity(0.08))
                RoundedRectangle(cornerRadius: 20)
                    .stroke(model.isDown == true ? Color.green : Color.secondary.opacity(0.3), lineWidth: 2)
                VStack(spacing: 12) {
                    Text(model.isDown.map { $0 ? "PRESSED" : "RELEASED" } ?? "PLUG IN YOUR BUTTON")
                        .font(.system(size: 23, weight: .semibold, design: .rounded))
                    TimelineView(.periodic(from: .now, by: 0.1)) { context in
                        Text(model.isDown == true ? String(format: "Held for %.1f seconds", max(0, context.date.timeIntervalSince(model.changedAt))) : "Press the physical key connected to GPIO4")
                            .font(.system(size: 13)).foregroundColor(.secondary)
                    }
                }
            }.frame(height: 150)
            HStack(alignment: .firstTextBaseline) {
                Text("\(model.count)").font(.system(size: 48, weight: .medium, design: .rounded)).monospacedDigit()
                Text("presses").foregroundColor(.secondary)
                Spacer()
                Button("Reset counter") { model.resetCount() }
            }
            VStack(alignment: .leading, spacing: 5) {
                if model.history.isEmpty {
                    Text("Your press and release events will appear here.").foregroundColor(.secondary)
                } else {
                    ForEach(Array(model.history.enumerated()), id: \.offset) { _, line in Text(line) }
                }
            }.font(.system(size: 12, design: .monospaced)).frame(height: 108, alignment: .topLeading)
            Divider()
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Wiring: GPIO4 → switch → GND").fontWeight(.medium)
                    Text("One press per push. Holding the key should not repeat.\nStuck on PRESSED? Check for a short or a held switch.")
                        .foregroundColor(.secondary)
                }.font(.system(size: 12))
                Spacer()
                Button("Reconnect") { model.reconnect() }
            }
        }.padding(30).frame(width: 550)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = TesterModel()
    var window: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let menu = NSMenu(); let appMenu = NSMenu(); let item = NSMenuItem()
        appMenu.addItem(withTitle: "Quit Button Tester", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.submenu = appMenu; menu.addItem(item); NSApp.mainMenu = menu
        let host = NSHostingView(rootView: TesterView(model: model))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 550, height: 640),
            styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "Blocked — Button Tester"; window.contentView = host
        window.setContentSize(host.fittingSize); window.center(); window.makeKeyAndOrderFront(nil)
        self.window = window; NSApp.activate(ignoringOtherApps: true); model.start()
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) { model.stop() }
}

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
