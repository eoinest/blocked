import Foundation

/// The transport boundary keeps reconnect policy testable without USB hardware.
public protocol ButtonSerialPort: AnyObject {
    func read() -> ButtonSerialRead
    func write(_ data: Data) -> Bool
    func close()
}

public enum ButtonSerialRead {
    case bytes(Data)
    case idle
    case disconnected
}

/// Call on one thread, using a monotonic clock that advances during sleep.
public final class SerialConnection {
    public var onPress: (() -> Void)?
    public var onStatus: ((String) -> Void)?
    private let discover: () -> [String]
    private let open: (String) -> ButtonSerialPort?
    private var port: ButtonSerialPort?
    private var path = ""
    private var buffer = Data()
    private var session = WireSession()
    private var openedAt: TimeInterval = 0
    private var lastPoll: TimeInterval?
    private var nextScan: TimeInterval = -.infinity
    private var lastHello: TimeInterval = 0
    private var retryAfter: [String: TimeInterval] = [:]

    public init(discover: @escaping () -> [String],
                open: @escaping (String) -> ButtonSerialPort? = { POSIXButtonSerialPort(path: $0) }) {
        self.discover = discover
        self.open = open
    }

    deinit { port?.close() }

    public func reconnect() {
        closePort()
        retryAfter.removeAll()
        lastPoll = nil
        onStatus?("Looking for your button…")
    }

    public func stop() { closePort(); lastPoll = nil }

    public func result(_ value: String) {
        guard port != nil else { return }
        if !send("RESULT \(value)\n") { disconnected() }
    }

    private func closePort() {
        port?.close()
        port = nil
        path = ""
        buffer.removeAll()
        session = WireSession()
        nextScan = -.infinity
    }

    private func disconnected() {
        closePort()
        onStatus?("Button disconnected. Waiting for reconnection…")
    }

    private func send(_ line: String) -> Bool { port?.write(Data(line.utf8)) ?? false }

    public func poll(now: TimeInterval) {
        let stalled = lastPoll.map { now - $0 > 0.5 || now < $0 } ?? false
        lastPoll = now
        if stalled, port != nil {
            // Sleep or a blocked run loop can leave old complete or partial PRESS
            // frames in either buffer. Closing, flushing on open, and HELLO also
            // requires the firmware to observe a fresh release before rearming.
            closePort()
            onStatus?("Reconnecting your button after a pause…")
            return
        }
        guard let port else {
            guard now >= nextScan else { return }
            nextScan = now + 1
            let candidates = discover()
            retryAfter = retryAfter.filter { candidates.contains($0.key) && $0.value > now }
            guard let candidate = candidates.first(where: { now >= (retryAfter[$0] ?? -.infinity) }) else { return }
            guard let opened = open(candidate) else {
                retryAfter[candidate] = now + 1
                return
            }
            self.port = opened
            path = candidate
            openedAt = now
            lastHello = now
            session = WireSession()
            buffer.removeAll()
            guard send("HELLO\n") else { disconnected(); return }
            onStatus?("Connecting to your button…")
            return
        }
        if !session.identified, now - openedAt > 4 {
            retryAfter[path] = now + 10
            closePort()
            onStatus?("Button identity handshake failed. Retrying automatically…")
            return
        }
        if !session.identified, now - lastHello >= 0.5 {
            lastHello = now
            guard send("HELLO\n") else { disconnected(); return }
        }

        // Drain a bounded batch before delivering anything: HUP or an oversized
        // burst after a valid PRESS must discard that PRESS, too.
        var drained = false
        for _ in 0..<9 {
            switch port.read() {
            case .bytes(let data):
                guard !data.isEmpty else { disconnected(); return }
                buffer.append(data)
                if buffer.count > 4096 { break }
            case .idle: drained = true
            case .disconnected: disconnected(); return
            }
            if drained || buffer.count > 4096 { break }
        }
        guard drained, buffer.count <= 4096 else {
            closePort()
            onStatus?("Invalid button data. Reconnecting…")
            return
        }
        var presses = 0
        while let newline = buffer.firstIndex(of: 10) {
            let raw = buffer[..<newline]
            guard raw.count <= 64, let line = String(data: raw, encoding: .utf8) else {
                closePort(); onStatus?("Invalid button data. Reconnecting…"); return
            }
            buffer.removeSubrange(...newline)
            let wasIdentified = session.identified
            if session.accept(line.hasSuffix("\r") ? String(line.dropLast()) : line) { presses += 1 }
            if !wasIdentified && session.identified { onStatus?("Button connected") }
        }
        guard buffer.count <= 64 else {
            closePort(); onStatus?("Invalid button data. Reconnecting…"); return
        }
        // Buffered bursts are never replayed as actions.
        if presses == 1 { onPress?() }
    }
}
