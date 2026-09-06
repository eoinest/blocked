import Foundation
import Darwin

/// Shares GitHub CLI's existing account/configuration. Sign-in starts only on an
/// explicit call to signIn(); no token is read by or returned to the application.
public final class GitHubConnection {
    public enum State: Equatable {
        case checking
        case connected(String)
        case signInRequired(String)
        case deviceCode(String, URL)
        case failed(String)
    }

    public var onChange: ((State) -> Void)?
    private let executable: () -> String?
    private let loginTimeout: TimeInterval
    private let checkTimeout: TimeInterval
    private var generation = 0
    private var loginProcess: Process?

    public init(executable: @escaping () -> String?, loginTimeout: TimeInterval = 960, checkTimeout: TimeInterval = 20) {
        self.executable = executable
        self.loginTimeout = loginTimeout
        self.checkTimeout = checkTimeout
    }

    deinit { if let process = loginProcess { Self.stop(process) } }

    public func check() {
        onMain { [weak self] in self?.beginCheck() }
    }

    public func signIn() {
        onMain { [weak self] in self?.beginSignIn() }
    }

    public func cancel() {
        onMain { [weak self] in
            guard let self else { return }
            self.invalidate()
            self.onChange?(.signInRequired("Sign-in cancelled. You can try again when ready."))
        }
    }

    private func onMain(_ work: @escaping () -> Void) {
        if Thread.isMainThread { work() } else { DispatchQueue.main.async(execute: work) }
    }

    private func invalidate() {
        generation += 1
        if let process = loginProcess { Self.stop(process) }
        loginProcess = nil
    }

    private func beginCheck() {
        invalidate()
        let current = generation
        guard let path = executable() else {
            onChange?(.failed("GitHub CLI is missing. Reinstall Blocked or choose a GitHub CLI executable in Settings."))
            return
        }
        onChange?(.checking)
        guard generation == current else { return }
        do {
            try ReviewRunner.start(executable: path, arguments: ["api", "--hostname", "github.com", "user", "--jq", ".login"], timeout: checkTimeout) { [weak self] result in
                guard let self, self.generation == current else { return }
                if case .success(let output) = result,
                   let username = Self.username(output) {
                    self.onChange?(.connected(username))
                } else {
                    self.onChange?(.signInRequired("Connect your GitHub account. If you are already signed in, check your internet connection and try again."))
                }
            }
        } catch {
            onChange?(.failed("GitHub CLI could not start. Reinstall Blocked or check the executable selected in Settings."))
        }
    }

    private func beginSignIn() {
        invalidate()
        let current = generation
        guard let path = executable() else {
            onChange?(.failed("GitHub CLI is missing. Reinstall Blocked or choose a GitHub CLI executable in Settings."))
            return
        }
        onChange?(.checking)
        guard generation == current else { return }
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = ["auth", "login", "--hostname", "github.com", "--web", "--skip-ssh-key", "--clipboard=false"]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = pipe
        process.standardError = pipe
        var environment = ProcessInfo.processInfo.environment
        environment["GH_PROMPT_DISABLED"] = "1"
        environment["GH_PAGER"] = "cat"
        environment["NO_COLOR"] = "1"
        environment["GH_NO_UPDATE_NOTIFIER"] = "1"
        environment["GH_NO_EXTENSION_UPDATE_NOTIFIER"] = "1"
        // Debug HTTP logging can contain credential-related output. Preserve
        // HOME, GH_CONFIG_DIR, and auth environment variables for shared auth.
        environment.removeValue(forKey: "GH_DEBUG")
        environment.removeValue(forKey: "DEBUG")
        process.environment = environment
        let descriptor = pipe.fileHandleForReading.fileDescriptor
        guard fcntl(descriptor, F_SETFL, O_NONBLOCK) != -1 else {
            onChange?(.failed("Could not prepare GitHub sign-in. Please try again."))
            return
        }
        do { try process.run() } catch {
            try? pipe.fileHandleForReading.close()
            try? pipe.fileHandleForWriting.close()
            onChange?(.failed("GitHub CLI could not start. Reinstall Blocked or check the executable selected in Settings."))
            return
        }
        try? pipe.fileHandleForWriting.close()
        loginProcess = process
        let timeout = loginTimeout
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var parser = GitHubDevicePromptParser()
            var bytes = [UInt8](repeating: 0, count: 4096)
            let deadline = ProcessInfo.processInfo.systemUptime + timeout
            var timedOut = false
            func drain() {
                // Keep noisy children from starving the timeout/cancel checks.
                for _ in 0..<16 {
                    let count = Darwin.read(descriptor, &bytes, bytes.count)
                    guard count > 0 else { break }
                    if let (code, url) = parser.append(Data(bytes.prefix(count))) {
                        DispatchQueue.main.async { [weak self] in
                            guard let self, self.generation == current else { return }
                            self.onChange?(.deviceCode(code, url))
                        }
                    }
                }
            }
            while process.isRunning {
                drain()
                if ProcessInfo.processInfo.systemUptime >= deadline {
                    timedOut = true
                    Self.stop(process)
                    break
                }
                Thread.sleep(forTimeInterval: 0.025)
            }
            process.waitUntilExit()
            drain()
            try? pipe.fileHandleForReading.close()
            let didTimeOut = timedOut
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == current else { return }
                self.loginProcess = nil
                if didTimeOut {
                    self.onChange?(.failed("GitHub sign-in expired. Start sign-in again to get a new code."))
                } else if process.terminationReason == .exit && process.terminationStatus == 0 {
                    // gh prints “Authentication complete” before saving auth;
                    // require success and then independently verify the account.
                    self.beginCheck()
                } else {
                    self.onChange?(.failed("GitHub sign-in did not complete. Try again, or check your connection and GitHub authorization. If you use a GitHub token environment variable, manage that token separately."))
                }
            }
        }
    }

    private static func stop(_ process: Process) {
        guard process.isRunning else { return }
        process.terminate()
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1) {
            if process.isRunning { Darwin.kill(process.processIdentifier, SIGKILL) }
        }
    }

    private static func username(_ output: String) -> String? {
        let value = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.range(of: #"\A[A-Za-z0-9](?:[A-Za-z0-9-]{0,37}[A-Za-z0-9])?\z"#, options: .regularExpression) != nil else { return nil }
        return value
    }
}

/// Recognizes only gh's device prompt, never arbitrary URLs or auth output.
/// Bounded line buffering also handles prompts split across pipe reads.
struct GitHubDevicePromptParser {
    private var line = Data()
    private var discardingLine = false
    private var code: String?
    private var url: URL?
    private var delivered = false

    mutating func append(_ data: Data) -> (String, URL)? {
        for byte in data {
            if byte == 10 {
                if !discardingLine { consume(String(decoding: line, as: UTF8.self)) }
                line.removeAll(keepingCapacity: true)
                discardingLine = false
            } else if line.count < 4096 && !discardingLine {
                line.append(byte)
            } else {
                line.removeAll(keepingCapacity: true)
                discardingLine = true
            }
        }
        guard !delivered, let code, let url else { return nil }
        delivered = true
        return (code, url)
    }

    private mutating func consume(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = "! First copy your one-time code: "
        if text.hasPrefix(prefix) {
            let candidate = String(text.dropFirst(prefix.count))
            if candidate.range(of: #"\A[A-Z0-9]{4}-[A-Z0-9]{4}\z"#, options: .regularExpression) != nil { code = candidate }
        }
        if text == "Open this URL to continue in your web browser: https://github.com/login/device" {
            url = URL(string: "https://github.com/login/device")
        }
    }
}
