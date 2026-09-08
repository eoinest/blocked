import Darwin
import XCTest
@testable import BlockedCore

final class SerialConnectionTests: XCTestCase {
    private final class Port: ButtonSerialPort {
        var reads: [ButtonSerialRead] = []
        var writes: [String] = []
        var closeCount = 0
        var writeSucceeds = true
        func enqueue(_ text: String) { reads.append(.bytes(Data(text.utf8))) }
        func read() -> ButtonSerialRead { reads.isEmpty ? .idle : reads.removeFirst() }
        func write(_ data: Data) -> Bool {
            writes.append(String(decoding: data, as: UTF8.self))
            return writeSucceeds
        }
        func close() { closeCount += 1 }
    }

    private final class Harness {
        let path = "/dev/cu.usbmodem-BLOCKED"
        var available = true
        var ports: [Port] = []
        var openedPaths: [String] = []
        var presses = 0
        var statuses: [String] = []
        var now: TimeInterval = 0
        lazy var connection: SerialConnection = {
            let connection = SerialConnection(discover: { [unowned self] in available ? [path] : [] }, open: { [unowned self] path in
                openedPaths.append(path)
                return ports.isEmpty ? nil : ports.removeFirst()
            })
            connection.onPress = { [unowned self] in presses += 1 }
            connection.onStatus = { [unowned self] in statuses.append($0) }
            return connection
        }()
        func poll(after interval: TimeInterval = 0.05) { now += interval; connection.poll(now: now) }
        func run(for duration: TimeInterval) {
            let end = now + duration
            while now < end { poll(after: 0.25) }
        }
        func connect(_ port: Port) {
            ports.append(port)
            poll()
            port.enqueue("BLOCKED_KEY 1\n")
            poll()
        }
    }

    func testUnplugAndReplugAtSamePathOpensNewSessionWithoutRestart() {
        let h = Harness(), first = Port(), replacement = Port()
        h.connect(first)
        first.enqueue("PRESS 100\n")
        h.poll()
        XCTAssertEqual(h.presses, 1)
        h.ports.append(replacement)
        first.reads.append(.disconnected)
        h.poll()
        XCTAssertEqual(first.closeCount, 1)
        h.poll()
        XCTAssertEqual(h.openedPaths, [h.path, h.path])
        XCTAssertEqual(replacement.writes, ["HELLO\n"])
        replacement.enqueue("PRESS 101\n")
        h.poll()
        XCTAssertEqual(h.presses, 1, "A previous session cannot bypass the new identity handshake")
        replacement.enqueue("BLOCKED_KEY 1\nPRESS 1\n")
        h.poll()
        XCTAssertEqual(h.presses, 2, "A reset board's sequence starts fresh after reconnect")
    }

    func testSleepDropsPartialAndQueuedFramesThenRequiresFreshIdentity() {
        let h = Harness(), first = Port(), replacement = Port()
        h.connect(first)
        first.enqueue("PRESS 1")
        h.poll()
        first.enqueue("\nPRESS 2\n")
        h.ports.append(replacement)
        h.poll(after: 60)
        XCTAssertEqual(first.closeCount, 1)
        XCTAssertEqual(h.presses, 0)
        h.poll()
        replacement.enqueue("\nPRESS 3\n")
        h.poll()
        XCTAssertEqual(h.presses, 0)
        replacement.enqueue("BLOCKED_KEY 1\nPRESS 1\n")
        h.poll()
        XCTAssertEqual(h.presses, 1)
    }

    func testDisconnectAfterQueuedPressDiscardsEntireReadBatch() {
        let h = Harness(), port = Port()
        h.connect(port)
        port.enqueue("PRESS 1\n")
        port.reads.append(.disconnected)
        h.poll()
        XCTAssertEqual(h.presses, 0)
        XCTAssertEqual(port.closeCount, 1)
    }

    func testBurstsAndDuplicateSequencesAreConsumedWithoutReplay() {
        let h = Harness(), port = Port()
        h.connect(port)
        port.enqueue("PRESS 1\nPRESS 2\n")
        h.poll()
        XCTAssertEqual(h.presses, 0)
        port.enqueue("PRESS 2\n")
        h.poll()
        XCTAssertEqual(h.presses, 0)
        port.enqueue("PRESS 3\r\n")
        h.poll()
        XCTAssertEqual(h.presses, 1)
        h.poll()
        XCTAssertEqual(h.presses, 1)
    }

    func testHandshakeRetriesTimesOutAndAutomaticallyRetries() {
        let h = Harness(), wrong = Port(), replacement = Port()
        h.ports = [wrong, replacement]
        h.poll()
        wrong.enqueue("BLOCKED_TEST 1\nPRESS 1\n")
        h.run(for: 4.25)
        XCTAssertEqual(wrong.closeCount, 1)
        XCTAssertGreaterThan(wrong.writes.count, 1)
        XCTAssertTrue(wrong.writes.allSatisfy { $0 == "HELLO\n" })
        XCTAssertEqual(h.presses, 0)
        h.run(for: 11)
        XCTAssertEqual(replacement.writes.first, "HELLO\n")
        replacement.enqueue("BLOCKED_KEY 1\nPRESS 1\n")
        h.poll()
        XCTAssertEqual(h.presses, 1)
    }

    func testAbsentOrTemporarilyBusyPortIsRetriedAutomatically() {
        let h = Harness(), port = Port()
        h.available = false
        h.run(for: 2)
        XCTAssertTrue(h.openedPaths.isEmpty)
        h.available = true
        h.run(for: 2)
        XCTAssertFalse(h.openedPaths.isEmpty, "Discovery resumes when a button is attached")
        h.ports.append(port)
        h.run(for: 1.25)
        XCTAssertEqual(port.writes.first, "HELLO\n", "A busy device can become available without app restart")
    }

    func testFailedWritesCloseAndReconnectWithoutQueuingCommands() {
        let h = Harness(), first = Port(), replacement = Port()
        first.writeSucceeds = false
        h.ports = [first, replacement]
        h.poll()
        XCTAssertEqual(first.closeCount, 1)
        h.poll()
        XCTAssertEqual(replacement.writes, ["HELLO\n"])
        replacement.enqueue("BLOCKED_KEY 1\n")
        h.poll()
        replacement.writeSucceeds = false
        h.connection.result("OK")
        XCTAssertEqual(replacement.closeCount, 1)
        h.connection.result("ERROR")
        XCTAssertEqual(replacement.writes, ["HELLO\n", "RESULT OK\n"])
    }

    func testOversizedOrInvalidUTF8FramesDiscardEarlierPressInBatch() {
        for payload in [Data(("PRESS 1\n" + String(repeating: "x", count: 65)).utf8),
                        Data([80, 82, 69, 83, 83, 32, 49, 10, 255, 10]),
                        Data(repeating: 120, count: 4097)] {
            let h = Harness(), port = Port()
            h.connect(port)
            port.reads.append(.bytes(payload))
            h.poll()
            XCTAssertEqual(h.presses, 0)
            XCTAssertEqual(port.closeCount, 1)
        }
    }

    func testContinuousInputIsBoundedAndNeverDispatchesPresses() {
        let h = Harness(), port = Port()
        h.connect(port)
        for _ in 0..<100 { port.enqueue("PRESS 1\n") }
        h.poll()
        XCTAssertEqual(h.presses, 0)
        XCTAssertEqual(port.closeCount, 1)
        XCTAssertEqual(port.reads.count, 91, "Do not let an untrusted device monopolize the UI run loop")
    }

    func testExplicitReconnectDiscardsSessionAndStopClosesPort() {
        let h = Harness(), first = Port(), replacement = Port()
        h.connect(first)
        first.enqueue("PRESS 1\n")
        h.ports.append(replacement)
        h.connection.reconnect()
        XCTAssertEqual(first.closeCount, 1)
        h.poll()
        XCTAssertEqual(replacement.writes, ["HELLO\n"])
        XCTAssertEqual(h.presses, 0)
        h.connection.stop()
        XCTAssertEqual(replacement.closeCount, 1)
    }

    func testPOSIXTransportDetectsHangupEvenWithQueuedBytes() throws {
        var descriptors = [Int32](repeating: -1, count: 2)
        XCTAssertEqual(pipe(&descriptors), 0)
        let reader = POSIXButtonSerialPort(ownedDescriptor: descriptors[0])
        defer { reader.close() }
        XCTAssertEqual(fcntl(descriptors[0], F_SETFL, O_NONBLOCK), 0)
        if case .idle = reader.read() {} else { XCTFail("Empty live transport must be idle") }
        let bytes = Array("PRESS 1\n".utf8)
        XCTAssertEqual(bytes.withUnsafeBytes { Darwin.write(descriptors[1], $0.baseAddress, $0.count) }, bytes.count)
        Darwin.close(descriptors[1])
        if case .disconnected = reader.read() {} else { XCTFail("HUP must discard queued bytes from the old connection") }
        reader.close()
        if case .disconnected = reader.read() {} else { XCTFail("Closed descriptors stay disconnected") }
    }

    func testPOSIXTransportReadsAvailableDataAndThenDetectsEOF() throws {
        var descriptors = [Int32](repeating: -1, count: 2)
        XCTAssertEqual(pipe(&descriptors), 0)
        let reader = POSIXButtonSerialPort(ownedDescriptor: descriptors[0])
        defer { reader.close() }
        XCTAssertEqual(fcntl(descriptors[0], F_SETFL, O_NONBLOCK), 0)
        let expected = Data("BLOCKED_KEY 1\n".utf8)
        XCTAssertEqual(expected.withUnsafeBytes { Darwin.write(descriptors[1], $0.baseAddress, $0.count) }, expected.count)
        if case .bytes(let actual) = reader.read() { XCTAssertEqual(actual, expected) }
        else { XCTFail("Ready bytes should be delivered") }
        if case .idle = reader.read() {} else { XCTFail("EAGAIN is not a disconnect") }
        Darwin.close(descriptors[1])
        if case .disconnected = reader.read() {} else { XCTFail("EOF must close the old session") }
    }
}
