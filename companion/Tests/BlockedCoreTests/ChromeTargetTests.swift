import XCTest
@testable import BlockedCore

final class ChromeTargetTests: XCTestCase {
    private let chrome = ChromeTarget.ApplicationIdentity(processID: 1234, bundleID: "com.google.Chrome")
    private let url = "https://github.com/example/repository/pull/42/files?diff=split#discussion"

    func testValidTargetPreservesWindowTabAndRawURLWhileCanonicalizingPR() throws {
        var frontmostReads = 0
        var fieldReads = 0
        let target = try ChromeTarget.read(frontmost: {
            frontmostReads += 1
            return chrome
        }, fields: {
            fieldReads += 1
            return ["105", "210", url]
        })

        XCTAssertEqual(target.processID, 1234)
        XCTAssertEqual(target.windowID, "105")
        XCTAssertEqual(target.tabID, "210")
        XCTAssertEqual(target.rawURL, url)
        XCTAssertEqual(target.pr.url, "https://github.com/example/repository/pull/42")
        XCTAssertEqual(frontmostReads, 2, "Verify focus both before and after the browser read")
        XCTAssertEqual(fieldReads, 1)
    }

    func testNonChromeOrMissingForegroundNeverReadsBrowser() {
        let identities: [ChromeTarget.ApplicationIdentity?] = [
            nil,
            .init(processID: 1234, bundleID: nil),
            .init(processID: 1234, bundleID: "com.apple.Safari"),
            .init(processID: 1234, bundleID: "com.google.Chrome.beta"),
            .init(processID: 1234, bundleID: "com.google.Chrome.evil")
        ]
        for identity in identities {
            var readBrowser = false
            XCTAssertThrowsError(try ChromeTarget.read(frontmost: { identity }, fields: {
                readBrowser = true
                return ["105", "210", url]
            }))
            XCTAssertFalse(readBrowser, "Do not request browser access unless Google Chrome is focused")
        }
    }

    func testForegroundPIDAppOrAvailabilityChangeRejectsCapturedURL() {
        let secondIdentities: [ChromeTarget.ApplicationIdentity?] = [
            nil,
            .init(processID: 9999, bundleID: "com.google.Chrome"),
            .init(processID: 1234, bundleID: "com.apple.Safari"),
            .init(processID: 1234, bundleID: nil)
        ]
        for second in secondIdentities {
            var reads = 0
            XCTAssertThrowsError(try ChromeTarget.read(frontmost: {
                reads += 1
                return reads == 1 ? chrome : second
            }, fields: { ["105", "210", url] }))
            XCTAssertEqual(reads, 2)
        }
    }

    func testMalformedFieldListsAndEmptyIdentitiesFailClosed() {
        let malformed: [[String]] = [
            [], ["105"], ["105", "210"], ["105", "210", url, "extra"],
            ["", "210", url], ["105", "", url], ["105", "210", ""]
        ]
        for fields in malformed {
            XCTAssertThrowsError(try ChromeTarget.read(frontmost: { chrome }, fields: { fields }),
                                 "Unexpected browser response must not become a target: \(fields)")
        }
    }

    func testIssuesSpoofHostsAndInvalidPRURLsFailClosed() {
        let invalidURLs = [
            "https://github.com/example/repository/issues/42",
            "https://github.com.evil.example/example/repository/pull/42",
            "https://github.com@evil.example/example/repository/pull/42",
            "https://user@github.com/example/repository/pull/42",
            "http://github.com/example/repository/pull/42",
            "https://github.com/example/repository/pull/not-a-number",
            "https://github.com/example/repository/pull/42/merge",
            "chrome://newtab/",
            "not a URL"
        ]
        for invalid in invalidURLs {
            XCTAssertThrowsError(try ChromeTarget.read(frontmost: { chrome }, fields: { ["105", "210", invalid] }), invalid)
        }
    }

    func testPermissionAndNoWindowErrorsPropagateWithoutFallbackTarget() {
        let errors = [
            NSError(domain: "NSAppleScriptError", code: -1743, userInfo: [NSLocalizedDescriptionKey: "Not authorized to send Apple events to Google Chrome."]),
            NSError(domain: "NSAppleScriptError", code: -2700, userInfo: [NSLocalizedDescriptionKey: "Chrome has no window"])
        ]
        for expected in errors {
            var reads = 0
            XCTAssertThrowsError(try ChromeTarget.read(frontmost: {
                reads += 1
                return chrome
            }, fields: { throw expected })) { error in
                let actual = error as NSError
                XCTAssertEqual(actual.domain, expected.domain)
                XCTAssertEqual(actual.code, expected.code)
                XCTAssertEqual(actual.localizedDescription, expected.localizedDescription)
            }
            XCTAssertEqual(reads, 1, "A failed field read must stop before producing a target")
        }
    }
}
