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
}
