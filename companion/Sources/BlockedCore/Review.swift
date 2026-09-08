import Foundation

public struct PullRequest: Equatable {
    public let owner: String
    public let repository: String
    public let number: String
    public var url: String { "https://github.com/\(owner)/\(repository)/pull/\(number)" }

    public init?(url raw: String) {
        guard let url = URLComponents(string: raw), url.scheme == "https",
              url.host == "github.com", url.user == nil, url.password == nil,
              url.port == nil, !url.percentEncodedPath.contains("%") else { return nil }
        let parts = url.path.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count >= 5, parts[0].isEmpty,
              Self.matches(String(parts[1]), "^[A-Za-z0-9](?:[A-Za-z0-9-]{0,38})$"),
              Self.matches(String(parts[2]), "^[A-Za-z0-9_.-]{1,100}$"),
              parts[2] != ".", parts[2] != "..", parts[3] == "pull",
              Self.matches(String(parts[4]), "^[1-9][0-9]{0,14}$") else { return nil }
        let tail = Array(parts.dropFirst(5))
        // GitHub's conversation, commits, checks and files views only.
        guard tail.isEmpty || tail == [""] ||
              (tail.count == 1 && ["files", "changes", "commits", "checks"].contains(String(tail[0]))) ||
              (tail.count == 2 && tail[1].isEmpty && ["files", "changes", "commits", "checks"].contains(String(tail[0]))) else { return nil }
        owner = String(parts[1]); repository = String(parts[2]); number = String(parts[4])
    }

    private static func matches(_ text: String, _ pattern: String) -> Bool {
        text.range(of: pattern, options: .regularExpression) != nil
    }
}

public enum ReviewAction: String, CaseIterable {
    case requestChanges, comment, approve
    public var title: String {
        switch self {
        case .requestChanges: return "Request changes"
        case .comment: return "Comment review"
        case .approve: return "Approve"
        }
    }
    public var flag: String {
        switch self {
        case .requestChanges: return "--request-changes"
        case .comment: return "--comment"
        case .approve: return "--approve"
        }
    }
}

public struct ReviewCommand {
    public let arguments: [String]
    public init(pr: PullRequest, action: ReviewAction, body: String) {
        arguments = ["pr", "review", pr.url, action.flag, "--body", body]
    }
}

/// Session identity is a compatibility check, not cryptographic authentication.
public struct WireSession {
    public private(set) var identified = false
    private var lastSequence: UInt64?
    public init() {}
    public mutating func accept(_ line: String) -> Bool {
        if line == "BLOCKED_KEY 1" { identified = true; return false }
        guard identified, line.hasPrefix("PRESS ") else { return false }
        let value = String(line.dropFirst(6))
        guard !value.isEmpty, value.allSatisfy({ $0.isASCII && $0.isNumber }),
              let sequence = UInt64(value), lastSequence.map({ sequence > $0 }) ?? true else { return false }
        lastSequence = sequence
        return true
    }
}

public struct PressGate {
    public private(set) var busy = false
    private var lastPress: TimeInterval = -.infinity
    private var lastSubmission: [String: TimeInterval] = [:]
    public init() {}
    public mutating func begin(now: TimeInterval) -> Bool {
        guard !busy, now - lastPress >= 2 else { return false }
        lastPress = now; busy = true
        return true
    }
    public mutating func finish() { busy = false }
    public mutating func reserveSubmission(_ pr: PullRequest, now: TimeInterval) -> Bool {
        guard now - (lastSubmission[pr.url] ?? -.infinity) >= 10 else { return false }
        // Keep the reservation on failure: a timed-out request may have reached GitHub.
        lastSubmission[pr.url] = now
        return true
    }
}
