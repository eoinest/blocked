import AppKit
import XCTest
@testable import BlockedCore

/// Opt-in because Apple Events requires a logged-in desktop and can request TCC permission.
/// Opens only disposable windows, never invokes gh, and restores the prior foreground app.
final class ChromeIntegrationTests: XCTestCase {
    private func script(_ source: String) throws -> NSAppleEventDescriptor {
        var error: NSDictionary?
        let result = try XCTUnwrap(NSAppleScript(source: source)).executeAndReturnError(&error)
        if let error { throw ReviewRunnerError(message: "Chrome integration AppleScript failed: \(error)") }
        return result
    }
    private func awaitForeground(_ pid: pid_t) throws {
        let deadline = ProcessInfo.processInfo.systemUptime + 3
        while NSWorkspace.shared.frontmostApplication?.processIdentifier != pid,
              ProcessInfo.processInfo.systemUptime < deadline {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        }
        guard NSWorkspace.shared.frontmostApplication?.processIdentifier == pid else {
            throw ReviewRunnerError(message: "Another app kept foreground focus during the Chrome smoke test. Run it again while the desktop is idle.")
        }
    }
    private func awaitFixture(window: Int32, path: String) throws {
        let deadline = ProcessInfo.processInfo.systemUptime + 5
        var fields = [String]()
        repeat {
            fields = try ChromeTarget.readScript()
            if fields.count == 3, fields[0] == String(window),
               URLComponents(string: fields[2])?.path == path { return }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        } while ProcessInfo.processInfo.systemUptime < deadline
        throw ReviewRunnerError(message: "Chrome fixture did not finish navigation in the expected window (expected \(window), observed \(fields.first ?? "missing")).")
    }
    func testRealChromeWindowsTabsAndNonPRRejection() throws {
        let mode = ProcessInfo.processInfo.environment["BLOCKED_CHROME_INTEGRATION"]
        guard mode == "1" || mode == "reader" else {
            throw XCTSkip("Run BLOCKED_CHROME_INTEGRATION=1 (full focus) or =reader (AppleScript only) swift test --filter ChromeIntegrationTests")
        }
        let fullFocus = mode == "1"
        let previous = NSWorkspace.shared.frontmostApplication
        var windows = [Int32]()
        defer {
            for id in windows { _ = try? script("tell application id \"com.google.Chrome\" to close (first window whose id is \(id))") }
            previous?.activate(options: [])
        }
        // These URLs are parser fixtures; the test does not require the PRs to exist.
        let first = try script("""
        tell application id "com.google.Chrome"
          set testWindow to make new window
          set URL of active tab of testWindow to "https://github.com/eoinest/blocked/pull/42/files?diff=split"
          set index of testWindow to 1
          activate
          return id of testWindow
        end tell
        """)
        windows.append(first.int32Value)
        try awaitFixture(window: windows[0], path: "/eoinest/blocked/pull/42/files")
        let chrome = try XCTUnwrap(NSRunningApplication.runningApplications(withBundleIdentifier: "com.google.Chrome").first)
        if fullFocus { try awaitForeground(chrome.processIdentifier) }
        func capture() throws -> ChromeTarget {
            if fullFocus { return try ChromeTarget.read() }
            // Reader-only mode uses real Apple Events, but deliberately injects app focus.
            // It must not be reported as verification of NSWorkspace foreground detection.
            return try ChromeTarget.read(frontmost: {
                ChromeTarget.ApplicationIdentity(processID: chrome.processIdentifier, bundleID: "com.google.Chrome")
            }, fields: ChromeTarget.readScript)
        }
        let firstTarget = try capture()
        XCTAssertEqual(firstTarget.windowID, String(windows[0]))
        XCTAssertEqual(firstTarget.pr.url, "https://github.com/eoinest/blocked/pull/42")

        _ = try script("""
        tell application id "com.google.Chrome"
          set testWindow to first window whose id is \(windows[0])
          make new tab at end of tabs of testWindow with properties {URL:"https://github.com/eoinest/blocked/pull/43/checks"}
          set active tab index of testWindow to count of tabs of testWindow
        end tell
        """)
        try awaitFixture(window: windows[0], path: "/eoinest/blocked/pull/43/checks")
        let secondTab = try capture()
        XCTAssertEqual(secondTab.windowID, firstTarget.windowID)
        XCTAssertNotEqual(secondTab.tabID, firstTarget.tabID)
        XCTAssertEqual(secondTab.pr.number, "43")

        let secondWindow = try script("""
        tell application id "com.google.Chrome"
          set testWindow to make new window
          set URL of active tab of testWindow to "https://github.com/eoinest/blocked/issues/44"
          set index of testWindow to 1
          activate
          return id of testWindow
        end tell
        """)
        windows.append(secondWindow.int32Value)
        try awaitFixture(window: windows[1], path: "/eoinest/blocked/issues/44")
        XCTAssertThrowsError(try capture(), "Front issue tab must not fall back to another window's PR")
        _ = try script("tell application id \"com.google.Chrome\" to set URL of active tab of (first window whose id is \(windows[1])) to \"https://github.com/eoinest/blocked/pull/44\"")
        try awaitFixture(window: windows[1], path: "/eoinest/blocked/pull/44")
        let otherWindow = try capture()
        XCTAssertEqual(otherWindow.windowID, String(windows[1]))
        XCTAssertEqual(otherWindow.pr.number, "44")
        if fullFocus, let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first {
            finder.activate(options: [])
            try awaitForeground(finder.processIdentifier)
            XCTAssertThrowsError(try ChromeTarget.read())
        }
    }
}
