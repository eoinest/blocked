import Foundation
import Darwin

public struct ReviewRunnerError: LocalizedError {
    public let message: String
    public var errorDescription: String? { message }
}

public enum ReviewRunner {
    public static func executable(custom: String) -> String? {
        let candidates = custom.isEmpty ? ["/opt/homebrew/bin/gh", "/usr/local/bin/gh", "/usr/bin/gh"] : [custom]
        return candidates.first { $0.hasPrefix("/") && FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Starts immediately on the caller's thread after its final focus check.
    /// Output goes to a private temporary file, so pipe backpressure cannot hang gh.
    public static func start(executable: String, arguments: [String], timeout: TimeInterval = 20, completion: @escaping (Result<String, Error>) -> Void) throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        let outputURL = directory.appendingPathComponent("output")
        _ = FileManager.default.createFile(atPath: outputURL.path, contents: nil, attributes: [.posixPermissions: 0o600])
        let output = try FileHandle(forWritingTo: outputURL)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = output; process.standardError = output
        process.standardInput = FileHandle.nullDevice
        var environment = ProcessInfo.processInfo.environment
        environment["GH_PROMPT_DISABLED"] = "1"; environment["GH_PAGER"] = "cat"; environment["NO_COLOR"] = "1"
        process.environment = environment
        do { try process.run() } catch {
            try? output.close(); try? FileManager.default.removeItem(at: directory); throw error
        }
        DispatchQueue.global(qos: .userInitiated).async {
            let deadline = ProcessInfo.processInfo.systemUptime + timeout
            while process.isRunning && ProcessInfo.processInfo.systemUptime < deadline { Thread.sleep(forTimeInterval: 0.05) }
            let timedOut = process.isRunning
            if timedOut {
                process.terminate()
                let killDeadline = ProcessInfo.processInfo.systemUptime + 1
                while process.isRunning && ProcessInfo.processInfo.systemUptime < killDeadline { Thread.sleep(forTimeInterval: 0.05) }
                if process.isRunning { Darwin.kill(process.processIdentifier, SIGKILL) }
            }
            process.waitUntilExit(); try? output.close()
            let text = (try? String(contentsOf: outputURL, encoding: .utf8)) ?? ""
            try? FileManager.default.removeItem(at: directory)
            let outcome: Result<String, Error>
            if timedOut { outcome = .failure(ReviewRunnerError(message: "GitHub timed out; it may have received the review. Check the PR before trying again.")) }
            else if process.terminationStatus != 0 { outcome = .failure(ReviewRunnerError(message: String(text.prefix(800)).trimmingCharacters(in: .whitespacesAndNewlines))) }
            else { outcome = .success(text) }
            DispatchQueue.main.async { completion(outcome) }
        }
    }
}
