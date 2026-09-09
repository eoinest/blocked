import Darwin
import XCTest
@testable import KeyCommandCore

final class CommandRunnerTests: XCTestCase {
    private var directory: URL!
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("key-command-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }
    private func runner() -> CommandRunner {
        // Avoid executing the developer's shell startup files in test fixtures.
        var env = ProcessInfo.processInfo.environment; env["ZDOTDIR"] = directory.path
        return CommandRunner(environment: env)
    }
    private func run(_ command: String, timeout: Double = 2, cwd: String? = nil) -> CommandResult {
        let done = expectation(description: "command finished")
        var result: CommandResult!
        let runner = runner()
        runner.start(command: command, directory: cwd ?? directory.path, timeout: timeout) { value in
            XCTAssertTrue(Thread.isMainThread); result = value; done.fulfill()
        }
        wait(for: [done], timeout: 5)
        return result
    }
    func testExactShellScriptAndWorkingDirectoryAreIndependent() throws {
        let working = directory.appendingPathComponent("work $(touch INJECTED) ; spaces")
        try FileManager.default.createDirectory(at: working, withIntermediateDirectories: false)
        let result = run("printf '%s\\n' 'literal $(touch INJECTED) ; quotes' ; /bin/pwd", cwd: working.path)
        XCTAssertEqual(result.end, .exited); XCTAssertEqual(result.exitCode, 0)
        XCTAssertTrue(result.output.contains("literal $(touch INJECTED) ; quotes"))
        XCTAssertTrue(result.output.contains(working.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: working.appendingPathComponent("INJECTED").path))
    }
    func testShellOperatorsIntentionallyWorkAndStderrExitStatusAreCaptured() {
        let result = run("value='hello world'; printf '%s' \"$value\"; printf ' error' >&2; exit 7")
        XCTAssertEqual(result.end, .exited); XCTAssertEqual(result.exitCode, 7)
        XCTAssertEqual(result.output, "hello world error")
    }
    func testNullStdinCannotWaitForUserInput() {
        let result = run("/bin/cat; printf eof")
        XCTAssertEqual(result.output, "eof"); XCTAssertEqual(result.exitCode, 0)
    }
    func testTimeoutBoundsOutputAndDoesNotDeadlock() {
        let result = run("/usr/bin/yes abcdefghijklmnopqrstuvwxyz", timeout: 0.15)
        XCTAssertEqual(result.end, .timedOut)
        XCTAssertTrue(result.truncated)
        XCTAssertEqual(result.output.utf8.count, 65_536)
    }
    func testCancellationKillsTermIgnoringChildProcessGroup() throws {
        let done = expectation(description: "cancelled")
        let runner = runner()
        let command = "trap '' TERM; /bin/zsh -c 'trap \"\" TERM; echo $$ > child.pid; while :; do /bin/sleep 1; done' & wait"
        var result: CommandResult?
        runner.start(command: command, directory: directory.path, timeout: 5) { value in result = value; done.fulfill() }
        let pidFile = directory.appendingPathComponent("child.pid")
        let deadline = Date().addingTimeInterval(2)
        while !FileManager.default.fileExists(atPath: pidFile.path), Date() < deadline { RunLoop.current.run(until: Date().addingTimeInterval(0.01)) }
        let pid = try XCTUnwrap(Int32(String(contentsOf: pidFile).trimmingCharacters(in: .whitespacesAndNewlines)))
        runner.cancel()
        wait(for: [done], timeout: 3)
        XCTAssertEqual(result?.end, .cancelled)
        let exitDeadline = Date().addingTimeInterval(2)
        while kill(pid, 0) == 0, Date() < exitDeadline { RunLoop.current.run(until: Date().addingTimeInterval(0.02)) }
        XCTAssertEqual(kill(pid, 0), -1, "A TERM-ignoring child must not survive cancellation")
        XCTAssertEqual(errno, ESRCH)
    }
    func testCancelledBeforeLaunchAndInvalidDirectoryNeverExecute() {
        let done = expectation(description: "pre-cancelled")
        let runner = runner(); runner.cancel()
        runner.start(command: "touch SHOULD_NOT_EXIST", directory: directory.path, timeout: 1) { result in
            XCTAssertEqual(result.end, .cancelled); done.fulfill()
        }
        wait(for: [done], timeout: 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("SHOULD_NOT_EXIST").path))
        XCTAssertEqual(run("printf nope", cwd: directory.appendingPathComponent("missing").path).end, .launchFailed)
    }
}
