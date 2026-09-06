import XCTest
import Darwin
@testable import BlockedCore

final class GitHubConnectionTests: XCTestCase {
    private func fake(_ source: String) throws -> URL {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("blocked-auth-test-" + UUID().uuidString)
        try ("#!/bin/sh\n" + source).write(to: path, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: path.path)
        addTeardownBlock { try? FileManager.default.removeItem(at: path) }
        return path
    }

    func testCheckUsesReadOnlyUserLookupAndMainThreadCallback() throws {
        let script = try fake("[ \"$*\" = 'api --hostname github.com user --jq .login' ] || exit 70\nprintf 'eoinest\\n'\n")
        let connection = GitHubConnection(executable: { script.path })
        let done = expectation(description: "existing account verified")
        var states: [GitHubConnection.State] = []
        connection.onChange = { state in
            XCTAssertTrue(Thread.isMainThread)
            states.append(state)
            if case .connected = state { done.fulfill() }
        }
        connection.check()
        wait(for: [done], timeout: 3)
        XCTAssertEqual(states, [.checking, .connected("eoinest")])
    }

    func testFailedCheckNeverStartsSignInOrLeaksOutput() throws {
        let script = try fake("[ \"$1\" = api ] || exit 70\necho 'sensitive-auth-output' >&2\nexit 1\n")
        let connection = GitHubConnection(executable: { script.path })
        let done = expectation(description: "sign-in required")
        connection.onChange = { state in
            if case .signInRequired(let message) = state {
                XCTAssertFalse(message.contains("sensitive-auth-output"))
                done.fulfill()
            }
        }
        connection.check()
        wait(for: [done], timeout: 3)
    }

    func testMalformedUsernameDoesNotConnect() throws {
        let script = try fake("printf 'eoinest\\nother-output\\n'\n")
        let connection = GitHubConnection(executable: { script.path })
        let done = expectation(description: "invalid output rejected")
        connection.onChange = { state in
            if case .connected = state { XCTFail("Malformed output must not become an account") }
            if case .signInRequired = state { done.fulfill() }
        }
        connection.check()
        wait(for: [done], timeout: 3)
    }

    func testSignInStreamsSplitCodeThenVerifiesAccountAfterExit() throws {
        let script = try fake("""
        if [ "$1" = api ]; then printf 'eoinest\\n'; exit 0; fi
        [ "$*" = 'auth login --hostname github.com --web --skip-ssh-key --clipboard=false' ] || exit 70
        [ "$GH_PROMPT_DISABLED|$NO_COLOR|$GH_NO_UPDATE_NOTIFIER" = '1|1|1' ] || exit 71
        if read input; then exit 72; fi
        printf '! First copy your one-time code: ABCD-' >&2
        /bin/sleep 0.1
        printf '1234\\n' >&2
        printf 'Open this URL to continue in your web browser: https://github.com/login/device\\n'
        /bin/sleep 0.1
        exit 0
        """)
        let connection = GitHubConnection(executable: { script.path })
        let done = expectation(description: "sign-in verified")
        var states: [GitHubConnection.State] = []
        connection.onChange = { state in
            XCTAssertTrue(Thread.isMainThread)
            states.append(state)
            if case .connected = state { done.fulfill() }
        }
        connection.signIn()
        wait(for: [done], timeout: 3)
        XCTAssertEqual(states, [.checking, .deviceCode("ABCD-1234", URL(string: "https://github.com/login/device")!), .checking, .connected("eoinest")])
    }

    func testSuccessLogBeforeFailedCredentialWriteDoesNotConnect() throws {
        let script = try fake("echo 'Authentication complete.' >&2\necho 'sensitive-auth-output' >&2\nexit 1\n")
        let connection = GitHubConnection(executable: { script.path })
        let done = expectation(description: "failed write")
        connection.onChange = { state in
            if case .connected = state { XCTFail("Logs are not proof of authentication") }
            if case .failed(let message) = state {
                XCTAssertFalse(message.contains("sensitive-auth-output"))
                done.fulfill()
            }
        }
        connection.signIn()
        wait(for: [done], timeout: 3)
    }

    func testTimeoutTerminatesChildAndRequiresExplicitRetry() throws {
        let script = try fake("trap '' TERM\nexec /bin/sleep 10\n")
        let connection = GitHubConnection(executable: { script.path }, loginTimeout: 0.05)
        let done = expectation(description: "login expired")
        var states: [GitHubConnection.State] = []
        connection.onChange = { state in
            states.append(state)
            if case .failed(let message) = state {
                XCTAssertTrue(message.contains("expired"))
                done.fulfill()
            }
        }
        connection.signIn()
        wait(for: [done], timeout: 3)
        XCTAssertEqual(states.count, 2)
    }

    func testCancelKillsChildAndSuppressesStaleCompletion() throws {
        let pidFile = FileManager.default.temporaryDirectory.appendingPathComponent("blocked-auth-pid-" + UUID().uuidString)
        addTeardownBlock { try? FileManager.default.removeItem(at: pidFile) }
        let script = try fake("""
        echo $$ > '\(pidFile.path)'
        trap '' TERM
        printf '! First copy your one-time code: ABCD-1234\\nOpen this URL to continue in your web browser: https://github.com/login/device\\n'
        exec /bin/sleep 10
        """)
        let connection = GitHubConnection(executable: { script.path })
        let cancelled = expectation(description: "cancelled")
        let stale = expectation(description: "no completion after cancellation")
        stale.isInverted = true
        var didCancel = false
        connection.onChange = { state in
            if didCancel { stale.fulfill(); return }
            if case .deviceCode = state { connection.cancel() }
            if case .signInRequired = state {
                didCancel = true
                cancelled.fulfill()
            }
        }
        connection.signIn()
        wait(for: [cancelled], timeout: 3)
        wait(for: [stale], timeout: 1.5)
        let pid = try XCTUnwrap(Int32(try String(contentsOf: pidFile).trimmingCharacters(in: .whitespacesAndNewlines)))
        XCTAssertEqual(Darwin.kill(pid, 0), -1, "Cancelled child should no longer exist")
    }

    func testMissingExecutableFailsWithoutLaunching() {
        let connection = GitHubConnection(executable: { nil })
        var states: [GitHubConnection.State] = []
        connection.onChange = { states.append($0) }
        connection.check()
        connection.signIn()
        XCTAssertEqual(states.count, 2)
        for state in states {
            guard case .failed(let message) = state else { return XCTFail("Expected missing CLI failure") }
            XCTAssertTrue(message.contains("missing"))
        }
    }

    func testParserRejectsUntrustedURLsMalformedCodesAndOversizedLines() {
        let badURLs = ["http://github.com/login/device", "https://github.com.evil.test/login/device", "https://github.com/login/device?token=secret", "https://evil.test", "https://github.com@evil.test/login/device"]
        for url in badURLs {
            var parser = GitHubDevicePromptParser()
            XCTAssertNil(parser.append(Data("! First copy your one-time code: ABCD-1234\nOpen this URL to continue in your web browser: \(url)\n".utf8)))
        }
        for code in ["abcd-1234", "ABCD-12345", "ABCD-1234 secret", "ghp_secret"] {
            var parser = GitHubDevicePromptParser()
            XCTAssertNil(parser.append(Data("! First copy your one-time code: \(code)\nOpen this URL to continue in your web browser: https://github.com/login/device\n".utf8)))
        }
        var parser = GitHubDevicePromptParser()
        XCTAssertNil(parser.append(Data((String(repeating: "x", count: 5000) + "! First copy your one-time code: ABCD-1234\nOpen this URL to continue in your web browser: https://github.com/login/device\n").utf8)))
        XCTAssertNotNil(parser.append(Data("! First copy your one-time code: ABCD-1234\n".utf8)))
        XCTAssertNil(parser.append(Data("! First copy your one-time code: ABCD-1234\n".utf8)), "Deliver only once per session")
    }
}
