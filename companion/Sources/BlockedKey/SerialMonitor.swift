import Foundation
import IOKit
import IOKit.serial
import BlockedCore

/// Main-run-loop polling keeps presses ordered with UI state. Reads never block.
final class SerialMonitor {
    var onPress: (() -> Void)?
    var onStatus: ((String) -> Void)?
    var manualPath = ""
    private var timer: Timer?
    private let clockOrigin = ContinuousClock.now
    private lazy var connection: SerialConnection = {
        let connection = SerialConnection(discover: { [weak self] in self?.discover() ?? [] })
        connection.onPress = { [weak self] in self?.onPress?() }
        connection.onStatus = { [weak self] in self?.onStatus?($0) }
        return connection
    }()

    func start() {
        guard timer == nil else { return }
        timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in self?.poll() }
        RunLoop.main.add(timer!, forMode: .common)
        poll()
    }
    deinit { timer?.invalidate() }
    func stop() { timer?.invalidate(); timer = nil; connection.stop() }
    func reconnect() { connection.reconnect() }
    func result(_ value: String) { connection.result(value) }

    private func poll() {
        // ContinuousClock advances while the Mac sleeps, unlike uptime clocks.
        let elapsed = clockOrigin.duration(to: .now).components
        connection.poll(now: Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18)
    }

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

}
