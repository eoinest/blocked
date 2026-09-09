import Foundation

public enum DeviceEvent: Equatable { case identified(String); case press(String) }

public struct ProtocolSession {
    public private(set) var deviceID: String?
    private var lastSequence: UInt32?
    public init() {}
    public static func validID(_ id: String) -> Bool {
        id.utf8.count == 12 && id.utf8.allSatisfy { (48...57).contains($0) || (65...70).contains($0) }
    }
    public mutating func accept(_ raw: String) -> DeviceEvent? {
        guard raw.utf8.prefix(97).count <= 96 else { return nil }
        let line = raw.hasSuffix("\r") ? String(raw.dropLast()) : raw
        if line.hasPrefix("KEY_COMMAND 1 ") {
            let id = String(line.dropFirst(14))
            guard Self.validID(id), deviceID == nil else { return nil }
            deviceID = id; return .identified(id)
        }
        guard let id = deviceID, line.hasPrefix("PRESS ") else { return nil }
        let rawNumber = line.dropFirst(6)
        guard !rawNumber.isEmpty, rawNumber.utf8.allSatisfy({ (48...57).contains($0) }),
              let sequence = UInt32(rawNumber),
              lastSequence.map({ let delta = sequence &- $0; return delta > 0 && delta < 0x80000000 }) ?? true else { return nil }
        lastSequence = sequence; return .press(id)
    }
}
