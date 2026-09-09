import Darwin
import Foundation

public struct CommandResult: Equatable {
    public enum End: String { case exited, cancelled, timedOut, launchFailed }
    public let end: End
    public let exitCode: Int32
    public let output: String
    public let truncated: Bool
    public var summary: String {
        switch end {
        case .exited: return "Exited with status \(exitCode)"
        case .cancelled: return "Cancelled"
        case .timedOut: return "Stopped after timeout"
        case .launchFailed: return "Could not start command"
        }
    }
}

/// One noninteractive zsh per invocation, in its own process group. Work and
/// output draining stay off the UI thread; retained output never exceeds 64 KiB.
public final class CommandRunner {
    private let lock = NSLock()
    private var cancelled = false
    private var started = false
    private var processGroup: pid_t?
    private let baseEnvironment: [String: String]
    public init(environment: [String: String] = ProcessInfo.processInfo.environment) { baseEnvironment = environment }
    public func cancel(force: Bool = false) {
        lock.lock(); cancelled = true
        if let processGroup { Darwin.kill(-processGroup, force ? SIGKILL : SIGTERM) }
        lock.unlock()
    }
    private var shouldCancel: Bool { lock.lock(); defer { lock.unlock() }; return cancelled }

    public func start(command: String, directory: String, timeout: TimeInterval,
                      completion: @escaping (CommandResult) -> Void) {
        lock.lock()
        guard !started else { lock.unlock(); return }
        started = true; lock.unlock()
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let result = execute(command: command, directory: directory, timeout: timeout)
            DispatchQueue.main.async { completion(result) }
        }
    }

    private func execute(command: String, directory: String, timeout: TimeInterval) -> CommandResult {
        func failed(_ text: String) -> CommandResult { .init(end: .launchFailed, exitCode: -1, output: text, truncated: false) }
        guard !command.contains("\0"), !directory.contains("\0"), timeout.isFinite, timeout > 0 else { return failed("Invalid command settings.") }
        if shouldCancel { return .init(end: .cancelled, exitCode: -1, output: "", truncated: false) }
        var pipes = [Int32](repeating: -1, count: 2)
        guard pipe(&pipes) == 0 else { return failed("Could not create command output pipe.") }
        defer { if pipes[0] >= 0 { Darwin.close(pipes[0]) }; if pipes[1] >= 0 { Darwin.close(pipes[1]) } }
        _ = fcntl(pipes[0], F_SETFL, O_NONBLOCK)
        _ = fcntl(pipes[0], F_SETFD, FD_CLOEXEC)
        _ = fcntl(pipes[1], F_SETFD, FD_CLOEXEC)
        var actions: posix_spawn_file_actions_t?
        var attributes: posix_spawnattr_t?
        guard posix_spawn_file_actions_init(&actions) == 0, posix_spawnattr_init(&attributes) == 0 else { return failed("Could not configure command process.") }
        defer { posix_spawn_file_actions_destroy(&actions); posix_spawnattr_destroy(&attributes) }
        // addchdir changes only the spawned process, never the desktop app's cwd.
        let setup = [
            posix_spawn_file_actions_addopen(&actions, STDIN_FILENO, "/dev/null", O_RDONLY, 0),
            posix_spawn_file_actions_adddup2(&actions, pipes[1], STDOUT_FILENO),
            posix_spawn_file_actions_adddup2(&actions, pipes[1], STDERR_FILENO),
            posix_spawn_file_actions_addclose(&actions, pipes[0]),
            posix_spawn_file_actions_addclose(&actions, pipes[1]),
            posix_spawn_file_actions_addchdir_np(&actions, directory),
            posix_spawnattr_setpgroup(&attributes, 0),
            posix_spawnattr_setflags(&attributes, Int16(POSIX_SPAWN_SETPGROUP))
        ]
        guard setup.allSatisfy({ $0 == 0 }) else { return failed("Could not set the command working directory or process group.") }
        var environment = baseEnvironment
        environment["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:" + (environment["PATH"] ?? "")
        environment["TERM"] = "dumb"
        // The command is intentionally shell code, passed verbatim as one -c
        // argument. Device IDs, nicknames and working directories are never code.
        let arguments = ["/bin/zsh", "-lc", command]
        let argv = arguments.map { strdup($0) } + [nil]
        let envp = environment.map { strdup("\($0.key)=\($0.value)") } + [nil]
        defer { argv.forEach { free($0) }; envp.forEach { free($0) } }
        var pid: pid_t = 0
        let launched = argv.withUnsafeBufferPointer { argv in
            envp.withUnsafeBufferPointer { envp in
                posix_spawn(&pid, "/bin/zsh", &actions, &attributes, argv.baseAddress!, envp.baseAddress!)
            }
        }
        guard launched == 0 else { return failed("Could not launch zsh: \(String(cString: strerror(launched)))") }
        lock.lock(); processGroup = pid; lock.unlock()
        defer { lock.lock(); processGroup = nil; lock.unlock() }
        Darwin.close(pipes[1]); pipes[1] = -1
        let clock = ContinuousClock()
        let start = clock.now
        var stopAt: ContinuousClock.Instant?
        var end = CommandResult.End.exited
        var output = Data(), truncated = false
        var status: Int32 = 0
        var exited = false
        var sentKill = false
        func elapsed(_ from: ContinuousClock.Instant) -> Double {
            let duration = from.duration(to: clock.now).components
            return Double(duration.seconds) + Double(duration.attoseconds) / 1e18
        }
        func drain() {
            var bytes = [UInt8](repeating: 0, count: 4096)
            for _ in 0..<16 {
                let count = Darwin.read(pipes[0], &bytes, bytes.count)
                guard count > 0 else { break }
                let keep = min(count, max(0, 65_536 - output.count))
                output.append(contentsOf: bytes.prefix(keep))
                if keep < count { truncated = true }
            }
        }
        while true {
            drain()
            if stopAt == nil && (shouldCancel || elapsed(start) >= timeout) {
                end = shouldCancel ? .cancelled : .timedOut
                stopAt = clock.now
                Darwin.kill(-pid, SIGTERM)
            }
            if let stopAt, !sentKill, elapsed(stopAt) >= 0.35 {
                // Kill even if zsh has exited: its child may have ignored TERM.
                Darwin.kill(-pid, SIGKILL); sentKill = true
            }
            if !exited {
                let waited = waitpid(pid, &status, WNOHANG)
                if waited == pid || (waited < 0 && errno == ECHILD) { exited = true }
            }
            if exited && (stopAt == nil || sentKill) { drain(); break }
            Thread.sleep(forTimeInterval: 0.01)
        }
        let signal = status & 0x7f
        let exitCode = signal == 0 ? ((status >> 8) & 0xff) : 128 + signal
        return .init(end: end, exitCode: exitCode, output: String(decoding: output, as: UTF8.self), truncated: truncated)
    }
}
