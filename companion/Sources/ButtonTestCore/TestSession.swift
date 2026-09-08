/// Events emitted by the dedicated USB button-test firmware.
public enum TestEvent: Equatable {
    case connected
    case state(isDown: Bool, newPress: Bool)
}

/// One serial connection's test-protocol state. Create a new instance when the
/// port reconnects. Input is one line without LF; a trailing CR is accepted.
public struct TestSession {
    private var identified = false
    private var previousState: Bool?

    public init() {}

    public mutating func accept(_ line: String) -> TestEvent? {
        // Bound inspection even if a caller hands us an oversized frame.
        guard line.utf8.prefix(65).count <= 64 else { return nil }
        let frame = line.hasSuffix("\r") ? String(line.dropLast()) : line

        if frame == "BLOCKED_TEST 1" {
            guard !identified else { return nil }
            identified = true
            return .connected
        }

        guard identified else { return nil }
        let isDown: Bool
        switch frame {
        case "STATE UP": isDown = false
        case "STATE DOWN": isDown = true
        default: return nil
        }

        // The first state is a snapshot, including a button already held when
        // attached. Repeated states are heartbeats, not additional presses.
        let newPress = isDown && (previousState == false)
        previousState = isDown
        return .state(isDown: isDown, newPress: newPress)
    }
}
