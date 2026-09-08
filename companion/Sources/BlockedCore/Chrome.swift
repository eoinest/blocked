import AppKit
import Carbon

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
        }, fields: { try readFields(processID: $0) })
    }

    struct ApplicationIdentity: Equatable {
        let processID: pid_t
        let bundleID: String?
    }

    // Inject only the OS boundary; tests exercise the production validation below.
    static func read(frontmost: () -> ApplicationIdentity?, fields: (pid_t) throws -> [String]) throws -> ChromeTarget {
        guard let app = frontmost(), app.bundleID == "com.google.Chrome" else {
            throw BlockedError.message("Focus a Google Chrome pull request first.")
        }
        let result = try fields(app.processID)
        guard frontmost() == app else {
            throw BlockedError.message("Focus changed while reading Chrome. Focus your PR and press again.")
        }
        guard result.count == 3, !result[0].isEmpty, !result[1].isEmpty else {
            throw BlockedError.message("Chrome did not return a window and active tab. Focus your PR and press again.")
        }
        guard let pr = PullRequest(url: result[2]) else {
            throw BlockedError.message("The focused Chrome tab must be a github.com pull request.")
        }
        return ChromeTarget(processID: app.processID, windowID: result[0], tabID: result[1], rawURL: result[2], pr: pr)
    }

    // A bundle ID can resolve to a background automation instance of Chrome.
    // Address every read to the exact foreground PID captured above instead.
    static func readFields(processID: pid_t,
                           send: (NSAppleEventDescriptor) throws -> NSAppleEventDescriptor = {
                               try $0.sendEvent(options: [.waitForReply, .neverInteract], timeout: 2)
                           }) throws -> [String] {
        let window = object(want: "cwin", form: "indx", selector: .init(int32: 1), container: .null())
        let tab = property("acTa", of: window)
        return try [property("ID  ", of: window), property("ID  ", of: tab), property("URL ", of: tab)].map { field in
            let event = NSAppleEventDescriptor(eventClass: code("core"), eventID: code("getd"),
                targetDescriptor: .init(processIdentifier: processID),
                returnID: AEReturnID(kAutoGenerateReturnID), transactionID: AETransactionID(kAnyTransactionID))
            event.setParam(field, forKeyword: keyDirectObject)
            let reply: NSAppleEventDescriptor
            do { reply = try send(event) }
            catch { throw BlockedError.message("Chrome access failed. Check Blocked’s Chrome connection in Setup & connections. \(error.localizedDescription)") }
            if let error = reply.paramDescriptor(forKeyword: keyErrorNumber), error.int32Value != 0 {
                if error.int32Value == errAEEventNotPermitted {
                    throw BlockedError.message("Allow Blocked in System Settings → Privacy & Security → Automation → Google Chrome, then press again.")
                }
                throw BlockedError.message("Could not read Chrome’s active tab (\(error.int32Value)). Focus a Chrome PR window and press again.")
            }
            guard let value = reply.paramDescriptor(forKeyword: keyDirectObject)?.stringValue, !value.isEmpty else {
                throw BlockedError.message("Chrome returned an empty window or tab value. Focus your PR and press again.")
            }
            return value
        }
    }

    // Fixed Chrome scripting dictionary codes; no URL or user text becomes code.
    private static func code(_ text: String) -> OSType {
        text.utf8.reduce(0) { ($0 << 8) | OSType($1) }
    }
    private static func property(_ name: String, of container: NSAppleEventDescriptor) -> NSAppleEventDescriptor {
        object(want: "prop", form: "prop", selector: .init(typeCode: code(name)), container: container)
    }
    private static func object(want: String, form: String, selector: NSAppleEventDescriptor,
                               container: NSAppleEventDescriptor) -> NSAppleEventDescriptor {
        let record = NSAppleEventDescriptor.record()
        record.setDescriptor(.init(typeCode: code(want)), forKeyword: code("want"))
        record.setDescriptor(.init(enumCode: code(form)), forKeyword: code("form"))
        record.setDescriptor(selector, forKeyword: code("seld"))
        record.setDescriptor(container, forKeyword: code("from"))
        return record.coerce(toDescriptorType: code("obj "))!
    }
}
