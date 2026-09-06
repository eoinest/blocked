import AppKit
import BlockedCore

enum BlockedError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}

struct ChromeTarget: Equatable {
    let processID: pid_t
    let windowID: String
    let tabID: String
    let rawURL: String
    let pr: PullRequest

    static func read() throws -> ChromeTarget {
        guard let app = NSWorkspace.shared.frontmostApplication, app.bundleIdentifier == "com.google.Chrome" else {
            throw BlockedError.message("Focus a Google Chrome pull request first.")
        }
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
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == app.processIdentifier,
              result.numberOfItems == 3,
              let windowID = result.atIndex(1)?.stringValue,
              let tabID = result.atIndex(2)?.stringValue,
              let url = result.atIndex(3)?.stringValue,
              let pr = PullRequest(url: url) else {
            throw BlockedError.message("The focused Chrome tab must be a github.com pull request.")
        }
        return ChromeTarget(processID: app.processIdentifier, windowID: windowID, tabID: tabID, rawURL: url, pr: pr)
    }
}
