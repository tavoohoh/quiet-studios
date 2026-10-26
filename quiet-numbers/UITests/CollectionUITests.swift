import XCTest

/// Phase 5 acceptance: each reward can be applied from the Collection.
final class CollectionUITests: XCTestCase {
    @MainActor
    func testApplyingRewards() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetStore", "-unlockAll"]
        app.launch()

        app.buttons["Collection"].tap()
        app.buttons["Sage & Coral"].tap()
        app.buttons["Circle"].tap()
        app.buttons["New York"].tap()
        XCTAssertTrue(app.buttons["Sage & Coral"].isSelected)
        snapshot(app, "collection")

        app.buttons["back"].tap()
        app.buttons["New Game"].tap()
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 2))
        snapshot(app, "game-sage-coral")

        app.buttons["back"].tap()
        app.buttons["Settings"].tap()
        snapshot(app, "settings")

        // Leave the simulator as it was.
        app.buttons["back"].tap()
        app.buttons["Collection"].tap()
        app.buttons["Teal & Coral"].tap()
        app.buttons["Plain"].tap()
        app.buttons["SF Rounded"].tap()
    }

    /// Signed out of Game Center, leaderboards explain how to sign in instead of failing.
    @MainActor
    func testLeaderboardsSignedOut() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetStore"]
        app.launch()
        app.buttons["Leaderboards"].tap()
        XCTAssertTrue(app.staticTexts["Play with friends"].waitForExistence(timeout: 3))
        snapshot(app, "leaderboards-signed-out")
    }

    @MainActor
    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
