import XCTest
@testable import BlockedCore

final class ActivationStateTests: XCTestCase {
    func testInstallCannotEnableBeforeAccountAndChromeAreReady() {
        var state = ActivationState(setupComplete: false, enabled: true)
        XCTAssertFalse(state.enabled)
        XCTAssertFalse(state.enable(accountConnected: true, chromeAllowed: false))
        XCTAssertFalse(state.enable(accountConnected: false, chromeAllowed: true))
        XCTAssertFalse(state.setupComplete)
        XCTAssertTrue(state.enable(accountConnected: true, chromeAllowed: true))
        XCTAssertTrue(state.enabled)
    }
    func testEnabledAndPausedIntentSurviveRelaunch() {
        var state = ActivationState()
        XCTAssertTrue(state.enable(accountConnected: true, chromeAllowed: true))
        var relaunched = ActivationState(setupComplete: state.setupComplete, enabled: state.enabled)
        XCTAssertTrue(relaunched.enabled)
        relaunched.pause()
        let pausedRestart = ActivationState(setupComplete: relaunched.setupComplete, enabled: relaunched.enabled)
        XCTAssertTrue(pausedRestart.setupComplete)
        XCTAssertFalse(pausedRestart.enabled)
    }
    func testChangingActionRequiresAcceptingNewConfiguration() {
        var state = ActivationState(setupComplete: true, enabled: true)
        state.configurationChanged()
        XCTAssertFalse(state.enabled); XCTAssertFalse(state.setupComplete)
        XCTAssertTrue(state.enable(accountConnected: true, chromeAllowed: true))
    }
}
