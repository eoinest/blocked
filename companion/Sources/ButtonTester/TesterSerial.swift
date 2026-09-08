import Foundation
import AppKit
import IOKit
import IOKit.serial
import Darwin
import ButtonTestCore

/// Dedicated diagnostic client. This target has no GitHub or Chrome integration.
final class TesterSerial {
    var onEvent: ((TestEvent) -> Void)?
    var onStatus: ((String, Bool) -> Void)?
    private var timer: Timer?
    private var fd: Int32 = -1
    private var path = ""
    private var buffer = Data()
    private var session = TestSession()
    private var identified = false
    private var openedAt: TimeInterval = 0
    private var lastHello: TimeInterval = 0
    private var lastResponse: TimeInterval = 0
    private var nextScan: TimeInterval = 0
    private var lastStatus = ""

    func start() {
        guard timer == nil else { return }
        timer = Timer(timeInterval: 0.025, repeats: true) { [weak self] _ in self?.poll() }
        RunLoop.main.add(timer!, forMode: .common)
        poll()
    }
    func stop() { timer?.invalidate(); timer = nil; closePort() }
    func reconnect() { closePort(); nextScan = 0; status("Looking for your button…") }

    private func status(_ text: String, connected: Bool = false) {
        guard text != lastStatus else { return }
        lastStatus = text; onStatus?(text, connected)
    }
    private func discover() -> (ports: [String], setupBoard: Bool) {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault,
            IOServiceMatching(kIOSerialBSDServiceValue), &iterator) == KERN_SUCCESS else { return ([], false) }
        defer { IOObjectRelease(iterator) }
        var ports: [String] = []; var setup = false
        while true {
            let service = IOIteratorNext(iterator)
            if service == 0 { break }
            defer { IOObjectRelease(service) }
            func property(_ key: String) -> AnyObject? {
                IORegistryEntrySearchCFProperty(service, kIOServicePlane, key as CFString,
                    kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents))
            }
            guard (property("idVendor") as? NSNumber)?.intValue == 0x303a else { continue }
            if property("USB Product Name") as? String == "Blocked Key",
               let candidate = property(kIOCalloutDeviceKey) as? String { ports.append(candidate) }
            else { setup = true }
        }
        return (ports.sorted(), setup)
    }
    private func closePort() {
        if fd >= 0 { Darwin.close(fd) }
        fd = -1; identified = false; buffer.removeAll(); session = TestSession()
    }
    private func openPort(_ candidate: String, now: TimeInterval) {
        let opened = Darwin.open(candidate, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard opened >= 0 else { status("USB port busy. Quit Blocked and any serial monitor."); return }
        // Prevent another ordinary process from opening this device during the test.
        guard ioctl(opened, TIOCEXCL) == 0 else {
            Darwin.close(opened); status("Could not reserve the USB port. Close other serial apps."); return
        }
        var settings = termios()
        guard tcgetattr(opened, &settings) == 0 else { Darwin.close(opened); status("Could not read USB settings."); return }
        cfmakeraw(&settings)
        cfsetispeed(&settings, speed_t(B115200)); cfsetospeed(&settings, speed_t(B115200))
        settings.c_cflag |= tcflag_t(CLOCAL | CREAD)
        settings.c_cflag &= ~tcflag_t(CRTSCTS)
        guard tcsetattr(opened, TCSANOW, &settings) == 0 else { Darwin.close(opened); status("Could not configure USB."); return }
        _ = tcflush(opened, TCIOFLUSH)
        var signals = Int32(TIOCM_DTR | TIOCM_RTS)
        guard ioctl(opened, TIOCMBIS, &signals) == 0 else { Darwin.close(opened); status("Could not enable USB serial."); return }
        fd = opened; path = candidate; openedAt = now; lastHello = now; lastResponse = now
        session = TestSession(); buffer.removeAll(); identified = false
        status("USB found. Starting button test…")
        sendTest()
    }
    private func sendTest() {
        let bytes: [UInt8] = Array("TEST\n".utf8)
        let sent = bytes.withUnsafeBytes { Darwin.write(fd, $0.baseAddress, $0.count) }
        if sent != bytes.count {
            closePort(); nextScan = ProcessInfo.processInfo.systemUptime + 2
            status("USB write failed. Reconnect the board.")
        }
    }
    private func poll() {
        let now = ProcessInfo.processInfo.systemUptime
        if fd < 0 {
            guard now >= nextScan else { return }; nextScan = now + 2
            let companionRunning = NSWorkspace.shared.runningApplications.contains {
                $0.bundleIdentifier == "io.github.eoinest.blocked" || $0.executableURL?.lastPathComponent == "BlockedKey"
            }
            if companionRunning { status("Quit the Blocked menu-bar app before testing."); return }
            let devices = discover()
            if let candidate = devices.ports.first { openPort(candidate, now: now) }
            else { status(devices.setupBoard ? "ESP32 detected. Upload the test-enabled firmware, then tap RESET." : "Waiting for USB — plug in your flashed ESP32.") }
            return
        }
        guard FileManager.default.fileExists(atPath: path) else {
            closePort(); status("Button unplugged. Plug it back in to continue."); return
        }
        if (!identified && now - openedAt > 4) || (identified && now - lastResponse > 3) {
            let wasIdentified = identified; closePort(); nextScan = now + 5
            status(wasIdentified ? "Button stopped responding. Reconnecting…" : "Firmware needs an update: this tester requires TEST support.")
            return
        }
        if !identified && now - lastHello >= 0.5 { lastHello = now; sendTest(); if fd < 0 { return } }
        var bytes = [UInt8](repeating: 0, count: 1024)
        // Bound a single poll so malformed serial input cannot hang the UI.
        for _ in 0..<8 {
            let count = Darwin.read(fd, &bytes, bytes.count)
            if count > 0 { buffer.append(contentsOf: bytes.prefix(count)) }
            else if count < 0 && errno != EAGAIN && errno != EWOULDBLOCK {
                closePort(); status("USB disconnected. Waiting for reconnection…"); return
            } else { break }
            if buffer.count > 4096 { closePort(); status("Unexpected USB data. Reconnect the board."); return }
        }
        while let newline = buffer.firstIndex(of: 10) {
            let line = String(decoding: buffer[..<newline], as: UTF8.self).trimmingCharacters(in: .newlines)
            buffer.removeSubrange(...newline)
            guard let event = session.accept(line) else { continue }
            lastResponse = now
            if case .connected = event { identified = true; status("Connected · GPIO4", connected: true) }
            onEvent?(event)
        }
    }
}
