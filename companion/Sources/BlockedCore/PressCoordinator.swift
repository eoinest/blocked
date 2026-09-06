import Foundation

/// Runs on the main thread, including the submission completion callback.
/// The same flow is used by the menu-bar app and tests with a fake gh boundary.
public final class PressCoordinator {
    public typealias Submit = (String, [String], @escaping (Result<String, Error>) -> Void) throws -> Void
    private var gate = PressGate()
    private let readTarget: () throws -> ChromeTarget
    private let now: () -> TimeInterval
    private let executable: (String) -> String?
    private let submit: Submit

    public init(readTarget: @escaping () throws -> ChromeTarget = ChromeTarget.read,
                now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
                executable: @escaping (String) -> String? = ReviewRunner.executable,
                submit: @escaping Submit = { path, args, done in
                    try ReviewRunner.start(executable: path, arguments: args, completion: done)
                }) {
        self.readTarget = readTarget; self.now = now
        self.executable = executable; self.submit = submit
    }

    public func press(armed: Bool, action: ReviewAction, body: String, ghPath: String,
                      submitting: (String) -> Void = { _ in },
                      report: @escaping (String, String) -> Void) {
        let started = now()
        guard gate.begin(now: started) else { return }
        do {
            let first = try readTarget()
            let second = try readTarget()
            guard first == second, now() - started < 1 else {
                throw BlockedError.message("Focus changed or Chrome access took too long. Press again.")
            }
            let command = ReviewCommand(pr: first.pr, action: action, body: body)
            if !armed {
                gate.finish()
                report("DRY RUN: \(action.title)\n\(first.pr.url)\n\n\(body)", "DRY_RUN")
                return
            }
            guard let path = executable(ghPath) else {
                throw BlockedError.message("gh was not found. Install GitHub CLI and run gh auth login in Terminal, or set its absolute path in Settings.")
            }
            guard gate.reserveSubmission(first.pr, now: started) else {
                throw BlockedError.message("Already attempted this PR in the last minute. Check it before trying again.")
            }
            submitting("Submitting \(first.pr.owner)/\(first.pr.repository)#\(first.pr.number)…")
            try submit(path, command.arguments) { [weak self] outcome in
                guard let self else { return }
                self.gate.finish()
                switch outcome {
                case .success:
                    report("Posted \(action.title.lowercased())\n\(first.pr.url)\n\n\(body)", "OK")
                case .failure(let error): report(error.localizedDescription, "ERROR")
                }
            }
        } catch { gate.finish(); report(error.localizedDescription, "ERROR") }
    }
}
