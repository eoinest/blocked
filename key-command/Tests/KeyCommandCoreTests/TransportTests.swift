import XCTest
@testable import KeyCommandCore

final class TransportTests: XCTestCase {
    final class Port: ButtonSerialPort {
        var input: [ButtonSerialRead] = []
        var writes: [String] = []
        var closed = false
        func enqueue(_ text: String) { input.append(.bytes(Data(text.utf8))) }
        func read() -> ButtonSerialRead { input.isEmpty ? .idle : input.removeFirst() }
        func write(_ data: Data) -> Bool { writes.append(String(decoding: data, as: UTF8.self)); return !closed }
        func close() { closed = true }
    }
    func testMultiplePortsDispatchIndependentStableIDsAndSuppressConflicts() {
        let a = Port(), b = Port(), c = Port()
        var ports = ["a": a, "b": b]
        let hub = DeviceHub(discover: { Array(ports.keys) }, open: { ports[$0] })
        var pressed: [String] = []; hub.onPress = { pressed.append($0) }
        hub.poll(now: 0)
        XCTAssertEqual(a.writes, ["KEY_COMMAND_HELLO\n"])
        a.enqueue("KEY_COMMAND 1 AABBCCDDEEFF\nPRESS 1\n")
        b.enqueue("KEY_COMMAND 1 001122334455\nPRESS 1\n")
        hub.poll(now: 0.05)
        XCTAssertEqual(Set(pressed), ["AABBCCDDEEFF", "001122334455"])
        ports["c"] = c
        for i in 1...4 { hub.poll(now: 0.05 + Double(i) * 0.25) }
        c.enqueue("KEY_COMMAND 1 AABBCCDDEEFF\nPRESS 1\n")
        a.enqueue("PRESS 2\n")
        hub.poll(now: 1.1)
        XCTAssertEqual(pressed.count, 2)
        XCTAssertEqual(hub.conflictedIDs, ["AABBCCDDEEFF"])
        XCTAssertEqual(hub.onlineIDs, ["001122334455"])
        hub.stop()
    }
    func testSamePathReplacementRehandshakesAndDropsOldSessionFrames() {
        let old = Port(), new = Port()
        var candidates = [old, new]
        let connection = DeviceConnection(discover: { ["same-path"] }, open: { _ in candidates.isEmpty ? nil : candidates.removeFirst() })
        var presses = 0; connection.onPress = { presses += 1 }
        connection.poll(now: 0)
        old.enqueue("KEY_COMMAND 1 AABBCCDDEEFF\nPRESS 99\n")
        connection.poll(now: 0.05)
        XCTAssertEqual(presses, 1)
        old.enqueue("PRESS 100\n"); old.input.append(.disconnected)
        connection.poll(now: 0.1)
        XCTAssertTrue(old.closed); XCTAssertEqual(presses, 1)
        connection.poll(now: 0.15)
        new.enqueue("PRESS 1\n"); connection.poll(now: 0.2)
        XCTAssertEqual(presses, 1)
        new.enqueue("KEY_COMMAND 1 AABBCCDDEEFF\nPRESS 1\n")
        connection.poll(now: 0.25)
        XCTAssertEqual(presses, 2)
    }
    func testSleepPartialFramesAndBurstAreNotActions() {
        let old = Port(), new = Port()
        var ports = [old, new]
        let connection = DeviceConnection(discover: { ["path"] }, open: { _ in ports.isEmpty ? nil : ports.removeFirst() })
        var presses = 0; connection.onPress = { presses += 1 }
        connection.poll(now: 0)
        old.enqueue("KEY_COMMAND 1 AABBCCDDEEFF\nPRESS 1")
        connection.poll(now: 0.05)
        old.enqueue("\n")
        connection.poll(now: 60)
        XCTAssertTrue(old.closed); XCTAssertEqual(presses, 0)
        connection.poll(now: 60.05)
        new.enqueue("KEY_COMMAND 1 AABBCCDDEEFF\nPRESS 1\nPRESS 2\n")
        connection.poll(now: 60.1)
        XCTAssertEqual(presses, 0)
        new.enqueue("PRESS 2\n"); connection.poll(now: 60.15)
        XCTAssertEqual(presses, 0)
        new.enqueue("PRESS 3\n"); connection.poll(now: 60.2)
        XCTAssertEqual(presses, 1)
    }
}
