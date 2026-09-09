import XCTest
@testable import KeyCommandCore

final class CoreTests: XCTestCase {
    let id = "AABBCCDDEEFF"
    func testProtocolIdentityIsRequiredStrictAndStable() {
        var session = ProtocolSession()
        for line in ["PRESS 1", "BLOCKED_KEY 1", "KEY_COMMAND 2 AABBCCDDEEFF", "KEY_COMMAND 1 aabbccddeeff", "KEY_COMMAND 1 AABBCCDDEEFF extra", "KEY_COMMAND 1 ABC", String(repeating: "x", count: 1000)] {
            XCTAssertNil(session.accept(line), line)
        }
        XCTAssertEqual(session.accept("KEY_COMMAND 1 \(id)\r"), .identified(id))
        XCTAssertEqual(session.accept("PRESS 4"), .press(id))
        XCTAssertNil(session.accept("KEY_COMMAND 1 001122334455"))
        XCTAssertNil(session.accept("KEY_COMMAND 1 \(id)"))
        XCTAssertNil(session.accept("PRESS 4"))
        XCTAssertNil(session.accept("PRESS 3"))
        for line in ["PRESS -1", "PRESS +5", "PRESS 4294967296", "PRESS  5", "PRESS 5\n"] { XCTAssertNil(session.accept(line)) }
        XCTAssertEqual(session.accept("PRESS 5"), .press(id))
    }
    func testUInt32WrapAndFreshReconnect() {
        var session = ProtocolSession()
        _ = session.accept("KEY_COMMAND 1 \(id)")
        XCTAssertEqual(session.accept("PRESS 4294967295"), .press(id))
        XCTAssertEqual(session.accept("PRESS 0"), .press(id))
        XCTAssertEqual(session.accept("PRESS 1"), .press(id))
        XCTAssertNil(session.accept("PRESS 4294967295"))
        session = ProtocolSession()
        XCTAssertNil(session.accept("PRESS 1"))
        _ = session.accept("KEY_COMMAND 1 \(id)")
        XCTAssertEqual(session.accept("PRESS 1"), .press(id))
    }
    func testBindingsPersistByChipIDAndDefaultDisabled() throws {
        let suite = "KeyCommandTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = SettingsStore(defaults: defaults)
        var first = store.binding(for: id)
        XCTAssertFalse(first.enabled); XCTAssertNotNil(first.validationError)
        first.command = "printf first"; first.nickname = "Desk button"; first.enabled = true
        try store.save(first)
        var second = Binding(deviceID: "001122334455"); second.command = "printf second"
        try store.save(second)
        let reloaded = SettingsStore(defaults: defaults)
        XCTAssertEqual(reloaded.bindings[id], first)
        XCTAssertEqual(reloaded.bindings[second.deviceID], second)
        first.command = ""; XCTAssertThrowsError(try store.save(first))
        XCTAssertEqual(store.bindings[id]?.command, "printf first")
    }
    func testGateSeparatesDevicesDropsBusyAndRespectsDisableAndDiagnostics() {
        var gate = ActionGate(), first = Binding(deviceID: id), second = Binding(deviceID: "001122334455")
        first.command = "printf first"; second.command = "printf second"
        XCTAssertFalse(gate.begin(first, now: 1))
        first.enabled = true; second.enabled = true
        XCTAssertTrue(gate.begin(first, now: 2))
        XCTAssertFalse(gate.begin(first, now: 3))
        XCTAssertTrue(gate.begin(second, now: 3))
        gate.finish(id); first.diagnosticsOnly = true
        XCTAssertFalse(gate.begin(first, now: 4))
        first.diagnosticsOnly = false; first.enabled = false
        XCTAssertFalse(gate.begin(first, now: 5))
        XCTAssertTrue(gate.begin(first, now: 5, test: true))
    }
    func testShortcutValidationPermissionFocusAndHeldKeyGuards() {
        let shortcut = Shortcut(keyCode: 40, modifiers: 1 << 20, label: "⌘K")
        XCTAssertTrue(shortcut.isValid)
        XCTAssertNil(shortcut.blockReason(trusted: true, targetPID: 10, ownPID: 20, heldModifiers: 0, keyHeld: false))
        XCTAssertNotNil(shortcut.blockReason(trusted: false, targetPID: 10, ownPID: 20, heldModifiers: 0, keyHeld: false))
        XCTAssertNotNil(shortcut.blockReason(trusted: true, targetPID: 20, ownPID: 20, heldModifiers: 0, keyHeld: false))
        XCTAssertNotNil(shortcut.blockReason(trusted: true, targetPID: nil, ownPID: 20, heldModifiers: 0, keyHeld: false))
        XCTAssertNotNil(shortcut.blockReason(trusted: true, targetPID: 10, ownPID: 20, heldModifiers: 1 << 17, keyHeld: false))
        XCTAssertNotNil(shortcut.blockReason(trusted: true, targetPID: 10, ownPID: 20, heldModifiers: 0, keyHeld: true))
        XCTAssertFalse(Shortcut(keyCode: 55, modifiers: 0, label: "⌘").isValid)
        XCTAssertFalse(Shortcut(keyCode: 255, modifiers: 0, label: "invalid").isValid)
        XCTAssertFalse(Shortcut(keyCode: 40, modifiers: 1, label: "K").isValid)
    }
}
