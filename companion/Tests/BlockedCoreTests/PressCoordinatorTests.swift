import XCTest
@testable import BlockedCore

final class PressCoordinatorTests: XCTestCase {
    private static func target(_ number: Int = 42, window: String = "1", tab: String = "2", pid: Int32 = 100, suffix: String = "") -> ChromeTarget {
        let url = "https://github.com/eoinest/blocked/pull/\(number)\(suffix)"
        return ChromeTarget(processID: pid, windowID: window, tabID: tab, rawURL: url, pr: PullRequest(url: url)!)
    }

    private final class Harness {
        var time: TimeInterval = 0
        var targets = [target(), target()]
        var reads = 0
        var readDelay: TimeInterval = 0
        var readError: Error?
        var launchError: Error?
        var path: String? = "/fake/gh"
        var lookups = 0
        var commands = [[String]]()
        var reports = [(String, String)]()
        var completion: ((Result<String, Error>) -> Void)?
        lazy var coordinator = PressCoordinator(readTarget: {
            self.reads += 1
            self.time += self.readDelay
            if let error = self.readError { throw error }
            return self.targets[min(self.reads - 1, self.targets.count - 1)]
        }, now: { self.time }, executable: { _ in
            self.lookups += 1
            return self.path
        }, submit: { _, args, done in
            self.commands.append(args)
            if let error = self.launchError { throw error }
            self.completion = done
        })
        func press(armed: Bool = true) {
            coordinator.press(armed: armed, action: .requestChanges, body: "blocked", ghPath: "",
                              report: { self.reports.append(($0, $1)) })
        }
    }

    func testDryRunReadsChromeButNeverLooksUpOrLaunchesGH() {
        let h = Harness(); h.press(armed: false)
        XCTAssertEqual(h.reads, 2); XCTAssertEqual(h.lookups, 0); XCTAssertTrue(h.commands.isEmpty)
        XCTAssertEqual(h.reports.first?.0, "DRY RUN: Request changes\nhttps://github.com/eoinest/blocked/pull/42\n\nblocked")
        XCTAssertEqual(h.reports.first?.1, "DRY_RUN")
        h.time = 2; h.press()
        XCTAssertEqual(h.commands.count, 1, "Dry run must not reserve a live submission")
    }

    func testLiveRequestTargetsCapturedCanonicalPRAndReportsCompletion() {
        let h = Harness(); h.targets = [Self.target(suffix: "/files?diff=split#discussion_r1")]
        h.press()
        XCTAssertEqual(h.reads, 2)
        XCTAssertEqual(h.commands, [["pr", "review", "https://github.com/eoinest/blocked/pull/42", "--request-changes", "--body", "blocked"]])
        XCTAssertTrue(h.reports.isEmpty)
        h.targets = [Self.target(99)]
        h.completion?(.success(""))
        XCTAssertEqual(h.reports.first?.1, "OK")
        XCTAssertTrue(h.reports.first?.0.contains("pull/42") == true, "Completion must describe the submitted PR, not the current tab")
    }

    func testChangedApplicationWindowTabURLOrPRNeverSubmits() {
        for changed in [Self.target(pid: 101), Self.target(window: "9"), Self.target(tab: "9"), Self.target(suffix: "/files"), Self.target(43)] {
            let h = Harness(); h.targets = [Self.target(), changed]; h.press()
            XCTAssertTrue(h.commands.isEmpty); XCTAssertEqual(h.lookups, 0)
            XCTAssertEqual(h.reports.first?.1, "ERROR")
        }
    }

    func testSlowReadsAreDiscardedAtOneSecondBoundary() {
        for delay in [0.5, 1.0] {
            let h = Harness(); h.readDelay = delay; h.press()
            XCTAssertTrue(h.commands.isEmpty); XCTAssertEqual(h.reports.first?.1, "ERROR")
        }
        let h = Harness(); h.readDelay = 0.49; h.press()
        XCTAssertEqual(h.commands.count, 1)
    }

    func testBusyPressIsDiscardedWithoutReadingChromeOrQueuing() {
        let h = Harness(); h.press(); h.time = 10; h.press()
        XCTAssertEqual(h.reads, 2); XCTAssertEqual(h.commands.count, 1)
        h.completion?(.success(""))
        XCTAssertEqual(h.commands.count, 1)
    }

    func testFailedAttemptReservesSamePRForSixtySeconds() {
        let h = Harness(); h.press()
        h.completion?(.failure(ReviewRunnerError(message: "not authorized")))
        h.time = 2; h.press()
        XCTAssertEqual(h.commands.count, 1)
        XCTAssertTrue(h.reports.last?.0.contains("last minute") == true)
        h.time = 60; h.press()
        XCTAssertEqual(h.commands.count, 2)
    }

    func testAnotherPRCanBeSubmittedAfterDebounce() {
        let h = Harness(); h.press(); h.completion?(.success(""))
        h.targets = [Self.target(43)]; h.time = 1; h.press()
        XCTAssertEqual(h.commands.count, 1)
        h.time = 2; h.press()
        XCTAssertEqual(h.commands.count, 2)
        XCTAssertEqual(h.commands.last?[2], "https://github.com/eoinest/blocked/pull/43")
    }

    func testMissingGHDoesNotReservePRAndReadErrorsReleaseBusyGate() {
        let h = Harness(); h.path = nil; h.press()
        XCTAssertTrue(h.commands.isEmpty); XCTAssertTrue(h.reports.last?.0.contains("gh was not found") == true)
        h.path = "/fake/gh"; h.time = 2; h.press()
        XCTAssertEqual(h.commands.count, 1)
        let rejected = Harness(); rejected.readError = ReviewRunnerError(message: "Automation denied"); rejected.press()
        XCTAssertEqual(rejected.reports.last?.0, "Automation denied")
        XCTAssertEqual(rejected.reads, 1); XCTAssertEqual(rejected.lookups, 0)
        rejected.readError = nil; rejected.time = 2; rejected.press()
        XCTAssertEqual(rejected.commands.count, 1)
    }

    func testLaunchFailureReleasesBusyButRetainsConservativeReservation() {
        let h = Harness(); h.launchError = ReviewRunnerError(message: "launch failed"); h.press()
        XCTAssertEqual(h.reports.last?.0, "launch failed")
        h.launchError = nil; h.time = 2; h.press()
        XCTAssertEqual(h.commands.count, 1)
        h.time = 60; h.press(); XCTAssertEqual(h.commands.count, 2)
    }

    func testWholePressFlowThroughRealLocalFakeGHProcess() throws {
        let script = FileManager.default.temporaryDirectory.appendingPathComponent("blocked-integration-gh-" + UUID().uuidString)
        try "#!/bin/sh\nprintf '%s\\n' \"$@\"\n".write(to: script, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: script.path)
        defer { try? FileManager.default.removeItem(at: script) }
        let done = expectation(description: "captured PR submitted to fake gh")
        let coordinator = PressCoordinator(readTarget: { Self.target(suffix: "/checks") }, executable: { _ in script.path }, submit: { path, args, completion in
            try ReviewRunner.start(executable: path, arguments: args) { outcome in
                if case .success(let output) = outcome {
                    XCTAssertEqual(output, "pr\nreview\nhttps://github.com/eoinest/blocked/pull/42\n--request-changes\n--body\nblocked\n")
                } else { XCTFail("Fake gh should succeed") }
                completion(outcome)
            }
        })
        coordinator.press(armed: true, action: .requestChanges, body: "blocked", ghPath: "", report: { _, result in
            XCTAssertEqual(result, "OK"); done.fulfill()
        })
        wait(for: [done], timeout: 3)
        withExtendedLifetime(coordinator) {}
    }
}
