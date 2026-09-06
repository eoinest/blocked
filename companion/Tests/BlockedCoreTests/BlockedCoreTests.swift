import XCTest
@testable import BlockedCore

final class BlockedCoreTests: XCTestCase {
    func testCanonicalPullRequest() {
        for suffix in ["", "/", "/files", "/commits", "/checks", "/files/", "?diff=split#discussion_r1"] {
            XCTAssertEqual(PullRequest(url: "https://github.com/eoinest/blocked/pull/42" + suffix)?.url,
                           "https://github.com/eoinest/blocked/pull/42")
        }
    }
    func testRejectsNonPRAndAmbiguousURLs() {
        for url in ["http://github.com/a/b/pull/1", "https://github.com.evil.test/a/b/pull/1",
                    "https://github.com@evil.test/a/b/pull/1", "https://user@github.com/a/b/pull/1",
                    "https://github.com:443/a/b/pull/1", "https://github.com/a/b/issues/1",
                    "https://github.com/a/b/pull/0", "https://github.com/a/b/pull/1/merge",
                    "https://github.com/a/b/pull/1/files/abc", "https://github.com/a/b/pull/%31",
                    "https://github.com/a/b/pull/1//", "https://github.com/a/../pull/1",
                    "https://github.com/a/b/pull/1\n", "https://github.com/a/b/pull/-1"] {
            XCTAssertNil(PullRequest(url: url), url)
        }
    }
    func testBodyRemainsSingleArgument() {
        let body = "blocked; $(touch /tmp/nope)\n--approve"
        let command = ReviewCommand(pr: PullRequest(url: "https://github.com/a/b/pull/1")!, action: .requestChanges, body: body)
        XCTAssertEqual(command.arguments, ["pr", "review", "https://github.com/a/b/pull/1", "--request-changes", "--body", body])
    }
    func testWireIdentitySequenceAndReconnect() {
        var wire = WireSession()
        XCTAssertFalse(wire.accept("PRESS 1"))
        XCTAssertFalse(wire.accept("BLOCKED_KEY 2"))
        XCTAssertFalse(wire.accept("PRESS 2"))
        XCTAssertFalse(wire.accept("BLOCKED_KEY 1"))
        XCTAssertTrue(wire.accept("PRESS 3"))
        XCTAssertFalse(wire.accept("PRESS 3"))
        XCTAssertFalse(wire.accept("PRESS 2"))
        XCTAssertFalse(wire.accept("PRESS -1"))
        XCTAssertFalse(wire.accept("PRESS 4 junk"))
        XCTAssertFalse(wire.accept("BLOCKED_KEY 1"))
        XCTAssertFalse(wire.accept("PRESS 3"))
        wire = WireSession()
        XCTAssertFalse(wire.accept("PRESS 4"))
    }
    func testBusyCooldownAndAmbiguousFailureReservation() {
        var gate = PressGate()
        XCTAssertTrue(gate.begin(now: 0))
        XCTAssertFalse(gate.begin(now: 5))
        gate.finish()
        XCTAssertFalse(gate.begin(now: 1))
        XCTAssertTrue(gate.begin(now: 2))
        let pr = PullRequest(url: "https://github.com/a/b/pull/1")!
        XCTAssertTrue(gate.reserveSubmission(pr, now: 2))
        XCTAssertFalse(gate.reserveSubmission(pr, now: 61))
        XCTAssertTrue(gate.reserveSubmission(pr, now: 62))
    }
}
