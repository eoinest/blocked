import Foundation
import IOKit
import IOKit.serial
import Darwin
import BlockedCore

/// Main-run-loop polling keeps presses ordered with UI state. Reads never block.
final class SerialMonitor {
    var onPress: (() -> Void)?
    var onStatus: ((String) -> Void)?
    var manualPath = ""
    private var descriptor: Int32 = -1
    private var timer: Timer?
    private var path = ""
    private var buffer = Data()
    private var session = WireSession()
    private var openedAt: TimeInterval = 0
    private var lastPoll: TimeInterval = 0
    private var lastScan: TimeInterval = -.infinity
    private var lastHello: TimeInterval = 0
    private var retryAfter: [String: TimeInterval] = [:]

    func start() {
        timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in self?.poll() }
        RunLoop.main.add(timer!, forMode: .common)
    }
    func reconnect() { closePort(); lastScan = -.infinity }
    func result(_ value: String) { send("RESULT \(value)\n") }

    private func discover() -> [String] {
        if !manualPath.isEmpty {
            guard manualPath.hasPrefix("/dev/cu."), !manualPath.dropFirst(5).contains("/") else { return [] }
            return [manualPath]
        }
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching(kIOSerialBSDServiceValue), &iterator) == KERN_SUCCESS else { return [] }
        defer { IOObjectRelease(iterator) }
        var paths: [String] = []
        while true {
            let service = IOIteratorNext(iterator)
            if service == 0 { break }
            defer { IOObjectRelease(service) }
            func property(_ name: String) -> AnyObject? {
                IORegistryEntrySearchCFProperty(service, kIOServicePlane, name as CFString, kCFAllocatorDefault,
                    IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents))
            }
            let product = property("USB Product Name") as? String
            let vendor = property("idVendor") as? NSNumber
            if product == "Blocked Key", vendor?.intValue == 0x303a,
               let port = property(kIOCalloutDeviceKey) as? String { paths.append(port) }
        }
        return paths.sorted()
    }

    private func openPort(_ candidate: String, now: TimeInterval) {
        let fd = Darwin.open(candidate, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard fd >= 0 else { retryAfter[candidate] = now + 5; return }
        var settings = termios()
        guard tcgetattr(fd, &settings) == 0 else { Darwin.close(fd); return }
        cfmakeraw(&settings)
        cfsetispeed(&settings, speed_t(B115200)); cfsetospeed(&settings, speed_t(B115200))
        settings.c_cflag |= tcflag_t(CLOCAL | CREAD)
        settings.c_cflag &= ~tcflag_t(CRTSCTS)
        guard tcsetattr(fd, TCSANOW, &settings) == 0 else { Darwin.close(fd); return }
        _ = tcflush(fd, TCIOFLUSH)
        var signals = Int32(TIOCM_DTR | TIOCM_RTS)
        guard ioctl(fd, TIOCMBIS, &signals) == 0 else { Darwin.close(fd); return }
        descriptor = fd; path = candidate; openedAt = now; lastHello = now
        session = WireSession(); buffer.removeAll()
        send("HELLO\n")
        onStatus?("Connecting to your button…")
    }
    private func closePort() {
        if descriptor >= 0 { Darwin.close(descriptor) }
        descriptor = -1; buffer.removeAll(); session = WireSession()
    }
    private func send(_ line: String) {
        guard descriptor >= 0 else { return }
        line.utf8CString.withUnsafeBufferPointer { bytes in
            _ = Darwin.write(descriptor, bytes.baseAddress!, bytes.count - 1)
        }
    }
    private func poll() {
        let now = ProcessInfo.processInfo.systemUptime
        let stale = lastPoll != 0 && now - lastPoll > 0.5
        lastPoll = now
        if descriptor < 0 {
            guard now - lastScan >= 2 else { return }
            lastScan = now
            if let candidate = discover().first(where: { now >= (retryAfter[$0] ?? 0) }) { openPort(candidate, now: now) }
            return
        }
        if !FileManager.default.fileExists(atPath: path) {
            closePort(); onStatus?("Button disconnected"); return
        }
        if !session.identified, now - openedAt > 4 {
            retryAfter[path] = now + 10; closePort(); onStatus?("Button identity handshake failed"); return
        }
        if !session.identified, now - lastHello >= 0.5 { send("HELLO\n"); lastHello = now }
        var bytes = [UInt8](repeating: 0, count: 512)
        var count: Int
        repeat {
            count = Darwin.read(descriptor, &bytes, bytes.count)
            if count > 0 { buffer.append(contentsOf: bytes.prefix(count)) }
            if buffer.count > 4096 { closePort(); onStatus?("Invalid button data"); return }
        } while count > 0
        if count < 0 && errno != EAGAIN && errno != EWOULDBLOCK {
            closePort(); onStatus?("Button disconnected"); return
        }
        var presses = 0
        while let newline = buffer.firstIndex(of: 10) {
            let line = String(decoding: buffer[..<newline], as: UTF8.self).trimmingCharacters(in: .newlines)
            buffer.removeSubrange(...newline)
            let wasIdentified = session.identified
            if session.accept(line) { presses += 1 }
            if !wasIdentified && session.identified { onStatus?("Button connected") }
        }
        // Consume but never execute buffered bursts or events delayed by sleep / dialogs.
        if presses == 1 && !stale { onPress?() }
    }
}
