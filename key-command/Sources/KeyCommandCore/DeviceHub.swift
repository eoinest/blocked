import Foundation

/// All callbacks run on the caller's polling thread. Ports are independent;
/// conflicting hardware identities cannot dispatch actions against one binding.
public final class DeviceHub {
    public var onPress: ((String) -> Void)?
    public var onChange: (() -> Void)?
    public private(set) var onlineIDs = Set<String>()
    public private(set) var conflictedIDs = Set<String>()
    public private(set) var portCount = 0
    private let discover: () -> [String]
    private let open: (String) -> ButtonSerialPort?
    private var connections: [String: DeviceConnection] = [:]
    private var pending: [String] = []
    private var nextScan: TimeInterval = -.infinity
    public init(discover: @escaping () -> [String], open: @escaping (String) -> ButtonSerialPort? = { POSIXButtonSerialPort(path: $0) }) {
        self.discover = discover; self.open = open
    }
    public func stop() { connections.values.forEach { $0.stop() }; connections.removeAll(); onlineIDs.removeAll(); nextScan = -.infinity }
    public func reconnect() { connections.values.forEach { $0.reconnect() }; nextScan = -.infinity }
    public func poll(now: TimeInterval) {
        let oldOnline = onlineIDs, oldConflicts = conflictedIDs, oldCount = portCount
        if now >= nextScan {
            nextScan = now + 1
            let paths = Set(discover())
            for path in Array(connections.keys) where !paths.contains(path) { connections.removeValue(forKey: path)?.stop() }
            for path in paths where connections[path] == nil {
                let connection = DeviceConnection(discover: { [path] }, open: open)
                connection.onPress = { [weak self, weak connection] in
                    if let id = connection?.deviceID { self?.pending.append(id) }
                }
                connections[path] = connection
            }
        }
        pending.removeAll()
        connections.values.forEach { $0.poll(now: now) }
        let grouped = Dictionary(grouping: connections.values.compactMap(\.deviceID), by: { $0 })
        onlineIDs = Set(grouped.filter { $0.value.count == 1 }.keys)
        conflictedIDs = Set(grouped.filter { $0.value.count > 1 }.keys)
        portCount = connections.count
        if oldOnline != onlineIDs || oldConflicts != conflictedIDs || oldCount != portCount { onChange?() }
        let batch = Dictionary(grouping: pending, by: { $0 })
        for (id, events) in batch where events.count == 1 && onlineIDs.contains(id) { onPress?(id) }
        pending.removeAll()
    }
}
