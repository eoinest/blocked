import Foundation

/// Persisted user intent; hardware disconnects and app restarts never change it.
public struct ActivationState: Equatable {
    public private(set) var setupComplete: Bool
    public private(set) var enabled: Bool
    public init(setupComplete: Bool = false, enabled: Bool = false) {
        self.setupComplete = setupComplete
        self.enabled = setupComplete && enabled
    }
    public mutating func enable(accountConnected: Bool, chromeAllowed: Bool) -> Bool {
        guard accountConnected, chromeAllowed else { return false }
        setupComplete = true; enabled = true
        return true
    }
    public mutating func pause() { enabled = false }
    public mutating func configurationChanged() { setupComplete = false; enabled = false }
}
