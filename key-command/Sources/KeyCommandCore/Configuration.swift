import Foundation

public enum ActionKind: String, Codable, CaseIterable { case command, shortcut }

public struct Shortcut: Codable, Equatable {
    public var keyCode: UInt16
    public var modifiers: UInt64
    public var label: String
    public init(keyCode: UInt16, modifiers: UInt64, label: String) {
        self.keyCode = keyCode; self.modifiers = modifiers; self.label = label
    }
    public static let allowedModifiers: UInt64 = (1 << 17) | (1 << 18) | (1 << 19) | (1 << 20)
    public var isValid: Bool {
        keyCode <= 126 && ![54, 55, 56, 57, 58, 59, 60, 61, 62, 63].contains(keyCode)
            && modifiers & ~Self.allowedModifiers == 0 && !label.isEmpty
    }
    public func blockReason(trusted: Bool, targetPID: Int32?, ownPID: Int32, heldModifiers: UInt64, keyHeld: Bool) -> String? {
        guard isValid else { return "No valid shortcut recorded." }
        guard trusted else { return "Allow keyboard shortcuts in Accessibility, then try again." }
        guard let targetPID, targetPID != ownPID else { return "Focus the destination app first. Key Command will not type into its own editor." }
        guard heldModifiers & Self.allowedModifiers == 0, !keyHeld else { return "Release held keyboard keys and modifiers, then press your button again." }
        return nil
    }
}

public struct Binding: Codable, Equatable {
    public var deviceID: String
    public var nickname: String
    public var kind: ActionKind = .command
    public var command = ""
    public var workingDirectory = FileManager.default.homeDirectoryForCurrentUser.path
    public var timeout: Double = 30
    public var shortcut: Shortcut?
    public var enabled = false
    public var diagnosticsOnly = false
    public init(deviceID: String) { self.deviceID = deviceID; self.nickname = "Button \(deviceID.suffix(4))" }
    public var validationError: String? {
        guard ProtocolSession.validID(deviceID) else { return "Invalid button identity." }
        if kind == .shortcut { return shortcut?.isValid == true ? nil : "Record a keyboard shortcut first." }
        guard !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !command.contains("\0") else { return "Enter a shell command first." }
        guard workingDirectory.hasPrefix("/"), !workingDirectory.contains("\0") else { return "Choose an absolute working directory." }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: workingDirectory, isDirectory: &isDirectory), isDirectory.boolValue else { return "The working directory does not exist." }
        guard timeout.isFinite, (1...3600).contains(timeout) else { return "Choose a timeout between 1 and 3600 seconds." }
        return nil
    }
}

public final class SettingsStore {
    private let defaults: UserDefaults
    private let key = "deviceBindings.v1"
    public private(set) var bindings: [String: Binding]
    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let decoded = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode([String: Binding].self, from: $0) } ?? [:]
        bindings = decoded.filter { ProtocolSession.validID($0.key) && $0.key == $0.value.deviceID }
    }
    public func binding(for id: String) -> Binding { bindings[id] ?? Binding(deviceID: id) }
    public func save(_ binding: Binding) throws {
        guard ProtocolSession.validID(binding.deviceID), !binding.enabled || binding.validationError == nil else {
            throw CommandError(binding.validationError ?? "Invalid device identity.")
        }
        var updated = bindings; updated[binding.deviceID] = binding
        let data = try JSONEncoder().encode(updated)
        defaults.set(data, forKey: key); bindings = updated
    }
}

public struct ActionGate {
    private var running = Set<String>()
    private var lastPress: [String: TimeInterval] = [:]
    public init() {}
    public func isRunning(_ id: String) -> Bool { running.contains(id) }
    public mutating func begin(_ binding: Binding, now: TimeInterval, test: Bool = false) -> Bool {
        guard !running.contains(binding.deviceID), binding.validationError == nil,
              test || (binding.enabled && !binding.diagnosticsOnly),
              now - (lastPress[binding.deviceID] ?? -.infinity) >= 0.3 else { return false }
        running.insert(binding.deviceID); lastPress[binding.deviceID] = now; return true
    }
    public mutating func finish(_ id: String) { running.remove(id) }
}

public struct CommandError: LocalizedError {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}
