import XCTest
@testable import BlockedCore

final class ReviewRunnerTests: XCTestCase {
    private func fake(_ source: String) throws -> URL {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("blocked-fake-gh-" + UUID().uuidString)
        try ("#!/bin/sh\n" + source).write(to: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: path.path)
        return path
    }
    func testPassesArgumentsWithoutShellEvaluation() throws {
        let script = try fake("printf '%s\\n' \"$@\"\n")
        defer { try? FileManager.default.removeItem(at: script) }
        let done = expectation(description: "subprocess completes")
        let body = "blocked; $(touch /tmp/should-never-execute)"
        try ReviewRunner.start(executable: script.path, arguments: ["--body", body]) { result in
            switch result {
            case .success(let output): XCTAssertEqual(output, "--body\n" + body + "\n")
            case .failure(let error): XCTFail(error.localizedDescription)
            }
            done.fulfill()
        }
        wait(for: [done], timeout: 3)
    }
    func testReportsNonzeroExit() throws {
        let script = try fake("echo 'not authorized' >&2\nexit 4\n")
        defer { try? FileManager.default.removeItem(at: script) }
        let done = expectation(description: "subprocess fails")
        try ReviewRunner.start(executable: script.path, arguments: []) { result in
            switch result {
            case .success: XCTFail("Expected failure")
            case .failure(let error): XCTAssertEqual(error.localizedDescription, "not authorized")
            }
            done.fulfill()
        }
        wait(for: [done], timeout: 3)
    }
    func testTimeoutHasAmbiguousSubmissionWarning() throws {
        let script = try fake("exec /bin/sleep 5\n")
        defer { try? FileManager.default.removeItem(at: script) }
        let done = expectation(description: "subprocess times out")
        try ReviewRunner.start(executable: script.path, arguments: [], timeout: 0.1) { result in
            switch result {
            case .success: XCTFail("Expected timeout")
            case .failure(let error): XCTAssertTrue(error.localizedDescription.contains("may have received"))
            }
            done.fulfill()
        }
        wait(for: [done], timeout: 3)
    }

    func testFullReviewCommandsReachProcessWithExactBlockedBody() throws {
        let script = try fake("printf '%s\\n' \"$@\"\n")
        defer { try? FileManager.default.removeItem(at: script) }
        let pr = try XCTUnwrap(PullRequest(url: "https://github.com/example/repository/pull/42/files?diff=split#discussion"))
        let actions: [(ReviewAction, String)] = [(.requestChanges, "--request-changes"), (.approve, "--approve"), (.comment, "--comment")]
        for (action, expectedFlag) in actions {
            let done = expectation(description: "\(action) invocation")
            let command = ReviewCommand(pr: pr, action: action, body: "blocked")
            try ReviewRunner.start(executable: script.path, arguments: command.arguments) { result in
                switch result {
                case .success(let output):
                    XCTAssertEqual(output, "pr\nreview\nhttps://github.com/example/repository/pull/42\n\(expectedFlag)\n--body\nblocked\n")
                case .failure(let error): XCTFail(error.localizedDescription)
                }
                done.fulfill()
            }
            wait(for: [done], timeout: 3)
        }
    }

    func testAuthenticationSelfReviewAndPermissionErrorsReachUser() throws {
        // Representative gh stderr fixtures; no real gh or GitHub access occurs.
        let messages = [
            "To get started with GitHub CLI, please run: gh auth login",
            "GraphQL: Can not request changes on your own pull request",
            "GraphQL: Resource not accessible by integration",
            "HTTP 404: Not Found"
        ]
        let script = try fake("printf '%s\\n' \"$1\" >&2\nexit 1\n")
        defer { try? FileManager.default.removeItem(at: script) }
        for message in messages {
            let done = expectation(description: message)
            try ReviewRunner.start(executable: script.path, arguments: [message]) { result in
                switch result {
                case .success: XCTFail("A failed review must not report success")
                case .failure(let error): XCTAssertEqual(error.localizedDescription, message)
                }
                done.fulfill()
            }
            wait(for: [done], timeout: 3)
        }
    }

    func testSilentFailureStillHasActionableMessage() throws {
        let script = try fake("exit 4\n")
        defer { try? FileManager.default.removeItem(at: script) }
        let done = expectation(description: "silent failure")
        try ReviewRunner.start(executable: script.path, arguments: []) { result in
            switch result {
            case .success: XCTFail("Expected failure")
            case .failure(let error):
                XCTAssertTrue(error.localizedDescription.contains("status 4"))
                XCTAssertTrue(error.localizedDescription.contains("gh auth status"))
            }
            done.fulfill()
        }
        wait(for: [done], timeout: 3)
    }

    func testRunnerDisablesInteractivePromptsAndProvidesEOFOnStdin() throws {
        let script = try fake("printf '%s|%s|%s\\n' \"$GH_PROMPT_DISABLED\" \"$GH_PAGER\" \"$NO_COLOR\"\nif read line; then exit 2; fi\n")
        defer { try? FileManager.default.removeItem(at: script) }
        let done = expectation(description: "noninteractive execution")
        try ReviewRunner.start(executable: script.path, arguments: []) { result in
            switch result {
            case .success(let output): XCTAssertEqual(output, "1|cat|1\n")
            case .failure(let error): XCTFail(error.localizedDescription)
            }
            done.fulfill()
        }
        wait(for: [done], timeout: 3)
    }

    func testTimedOutSubmissionIsNotAutomaticallyRetried() throws {
        let log = FileManager.default.temporaryDirectory.appendingPathComponent("blocked-attempts-" + UUID().uuidString)
        let script = try fake("printf 'attempt\\n' >> \"$1\"\nexec /bin/sleep 5\n")
        defer {
            try? FileManager.default.removeItem(at: script)
            try? FileManager.default.removeItem(at: log)
        }
        let done = expectation(description: "timeout without retry")
        try ReviewRunner.start(executable: script.path, arguments: [log.path], timeout: 0.2) { result in
            if case .success = result { XCTFail("Expected timeout") }
            done.fulfill()
        }
        wait(for: [done], timeout: 3)
        XCTAssertEqual(try String(contentsOf: log, encoding: .utf8), "attempt\n")
    }

    func testKilledProcessWarnsOfAmbiguousSubmission() throws {
        let script = try fake("kill -KILL $$\n")
        defer { try? FileManager.default.removeItem(at: script) }
        let done = expectation(description: "interrupted request")
        try ReviewRunner.start(executable: script.path, arguments: []) { result in
            switch result {
            case .success: XCTFail("Expected signal failure")
            case .failure(let error):
                XCTAssertTrue(error.localizedDescription.contains("signal 9"))
                XCTAssertTrue(error.localizedDescription.contains("may have received"))
            }
            done.fulfill()
        }
        wait(for: [done], timeout: 3)
    }

    func testMissingExecutableThrowsInsteadOfReportingSubmission() throws {
        XCTAssertNil(ReviewRunner.executable(custom: "relative/gh"))
        let missing = "/private/tmp/blocked-missing-gh-" + UUID().uuidString
        XCTAssertNil(ReviewRunner.executable(custom: missing))
        XCTAssertThrowsError(try ReviewRunner.start(executable: missing, arguments: []) { _ in
            XCTFail("A process that never started must not complete as a submitted review")
        })
    }
}
