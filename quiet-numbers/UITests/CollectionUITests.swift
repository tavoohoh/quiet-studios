import XCTest

/// Phase 5 acceptance: each reward can be applied from the Collection.
final class CollectionUITests: XCTestCase {
    @MainActor
    func testApplyingRewards() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetStore", "-unlockAll"]
        app.launch()

        app.buttons["Collection"].tap()
        app.buttons["Midnight"].tap()
        app.buttons["Circle"].tap()
        app.buttons["New York"].tap()
        XCTAssertTrue(app.buttons["Midnight"].isSelected)
        snapshot(app, "collection")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["New Game"].tap()
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 2))
        snapshot(app, "game-midnight")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Settings"].tap()
        snapshot(app, "settings")

        // Leave the simulator as it was.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Collection"].tap()
        app.buttons["Paper"].tap()
        app.buttons["Plain"].tap()
        app.buttons["SF Rounded"].tap()
    }

    @MainActor
    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
