import AppKit

enum BlockedError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

public struct ChromeTarget: Equatable {
    public let processID: pid_t
    public let windowID: String
    public let tabID: String
    public let rawURL: String
    public let pr: PullRequest

    public static func read() throws -> ChromeTarget {
        try read(frontmost: {
            guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
            return ApplicationIdentity(processID: app.processIdentifier, bundleID: app.bundleIdentifier)
        }, fields: readScript)
    }

    struct ApplicationIdentity: Equatable {
        let processID: pid_t
        let bundleID: String?
    }

    // Inject only the OS boundary; tests exercise the production validation below.
    static func read(frontmost: () -> ApplicationIdentity?, fields: () throws -> [String]) throws -> ChromeTarget {
        guard let app = frontmost(), app.bundleID == "com.google.Chrome" else {
            throw BlockedError.message("Focus a Google Chrome pull request first.")
        }
        let result = try fields()
        guard frontmost() == app, result.count == 3,
              !result[0].isEmpty, !result[1].isEmpty,
              let pr = PullRequest(url: result[2]) else {
            throw BlockedError.message("The focused Chrome tab must be a github.com pull request.")
        }
        return ChromeTarget(processID: app.processID, windowID: result[0], tabID: result[1], rawURL: result[2], pr: pr)
    }

    static func readScript() throws -> [String] {
        // Fixed script: no URL, review body, or user input is evaluated as code.
        let source = """
        with timeout of 2 seconds
          tell application id "com.google.Chrome"
            if (count of windows) is 0 then error "Chrome has no window"
            return {id of front window as text, id of active tab of front window as text, URL of active tab of front window}
          end tell
        end timeout
        """
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { throw BlockedError.message("Unable to create Chrome reader.") }
        let result = script.executeAndReturnError(&error)
        guard error == nil else {
            throw BlockedError.message("Chrome access failed. Allow Blocked in System Settings → Privacy & Security → Automation, then press again. \(error?[NSAppleScript.errorMessage] ?? "")")
        }
        guard result.numberOfItems == 3,
              let windowID = result.atIndex(1)?.stringValue,
              let tabID = result.atIndex(2)?.stringValue,
              let url = result.atIndex(3)?.stringValue else {
            throw BlockedError.message("The focused Chrome tab must be a github.com pull request.")
        }
        return [windowID, tabID, url]
    }
}
