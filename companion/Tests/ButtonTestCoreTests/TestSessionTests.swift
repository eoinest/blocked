import XCTest
import ButtonTestCore

final class TestSessionTests: XCTestCase {
    func testOnlyTestIdentityEnablesStateEvents() {
        var session = TestSession()
        for line in ["STATE UP", "STATE DOWN", "TEST", "BLOCKED_KEY 1", "PRESS 1", "BLOCKED_TEST 2"] {
            XCTAssertNil(session.accept(line), line)
        }
        XCTAssertEqual(session.accept("BLOCKED_TEST 1"), .connected)
        XCTAssertEqual(session.accept("STATE UP"), .state(isDown: false, newPress: false))
        XCTAssertEqual(session.accept("STATE DOWN"), .state(isDown: true, newPress: true))
    }

    func testButtonHeldAtConnectionIsDisplayedWithoutCounting() {
        var session = TestSession()
        XCTAssertEqual(session.accept("BLOCKED_TEST 1"), .connected)
        XCTAssertEqual(session.accept("STATE DOWN"), .state(isDown: true, newPress: false))
        XCTAssertEqual(session.accept("STATE DOWN"), .state(isDown: true, newPress: false))
        XCTAssertEqual(session.accept("STATE UP"), .state(isDown: false, newPress: false))
        XCTAssertEqual(session.accept("STATE DOWN"), .state(isDown: true, newPress: true))
    }

    func testHeartbeatStatesCountOnlyFreshDownEdges() {
        var session = TestSession()
        _ = session.accept("BLOCKED_TEST 1")
        let states = ["UP", "UP", "DOWN", "DOWN", "DOWN", "UP", "UP", "DOWN", "DOWN", "UP"]
        var presses = 0
        for state in states {
            guard case .state(let isDown, let newPress) = session.accept("STATE " + state) else {
                return XCTFail("Every valid state must report the current button state")
            }
            XCTAssertEqual(isDown, state == "DOWN")
            if newPress { presses += 1 }
        }
        XCTAssertEqual(presses, 2)
    }

    func testDuplicateIdentityPreservesBothHeldAndReleasedState() {
        var session = TestSession()
        _ = session.accept("BLOCKED_TEST 1")
        _ = session.accept("STATE UP")
        XCTAssertNil(session.accept("BLOCKED_TEST 1"))
        XCTAssertEqual(session.accept("STATE DOWN"), .state(isDown: true, newPress: true))
        XCTAssertNil(session.accept("BLOCKED_TEST 1"))
        XCTAssertEqual(session.accept("STATE DOWN"), .state(isDown: true, newPress: false))
    }

    func testMalformedFramesDoNotChangeStateOrEnableSession() {
        let invalid = ["", " ", "BLOCKED_TEST", "BLOCKED_TEST 0", "BLOCKED_TEST 01",
                       "BLOCKED_TEST 1 extra", " BLOCKED_TEST 1", "BLOCKED_TEST 1\n",
                       "state down", "STATE", "STATE HOLD", "STATE  DOWN", "STATE DOWN ",
                       "STATE DOWN\nSTATE UP", "STATE DOWN\0", "STATE ＤＯＷＮ",
                       "BLOCKED_KEY 1", "PRESS 42", String(repeating: "x", count: 65),
                       "STATE UP" + String(repeating: " ", count: 100_000)]
        var session = TestSession()
        for line in invalid { XCTAssertNil(session.accept(line)) }
        XCTAssertNil(session.accept("STATE UP"))
        _ = session.accept("BLOCKED_TEST 1")
        _ = session.accept("STATE UP")
        for line in invalid { XCTAssertNil(session.accept(line)) }
        XCTAssertEqual(session.accept("STATE DOWN"), .state(isDown: true, newPress: true))
        for line in invalid { XCTAssertNil(session.accept(line)) }
        XCTAssertEqual(session.accept("STATE DOWN"), .state(isDown: true, newPress: false))
    }

    func testCRLFTransportCanPassLinesWithTrailingCR() {
        var session = TestSession()
        XCTAssertEqual(session.accept("BLOCKED_TEST 1\r"), .connected)
        XCTAssertEqual(session.accept("STATE UP\r"), .state(isDown: false, newPress: false))
        XCTAssertEqual(session.accept("STATE DOWN\r"), .state(isDown: true, newPress: true))
        XCTAssertNil(session.accept("STATE UP\r\r"))
    }

    func testReconnectRequiresIdentityAndTreatsHeldStateAsSnapshotAgain() {
        var session = TestSession()
        _ = session.accept("BLOCKED_TEST 1")
        _ = session.accept("STATE UP")
        XCTAssertEqual(session.accept("STATE DOWN"), .state(isDown: true, newPress: true))

        session = TestSession()
        XCTAssertNil(session.accept("STATE UP"))
        XCTAssertNil(session.accept("STATE DOWN"))
        XCTAssertEqual(session.accept("BLOCKED_TEST 1"), .connected)
        XCTAssertEqual(session.accept("STATE DOWN"), .state(isDown: true, newPress: false))
        XCTAssertEqual(session.accept("STATE UP"), .state(isDown: false, newPress: false))
        XCTAssertEqual(session.accept("STATE DOWN"), .state(isDown: true, newPress: true))
    }
}
