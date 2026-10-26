import XCTest

/// Phase 3 acceptance: closing the app and coming back keeps the state.
final class PersistenceUITests: XCTestCase {
    @MainActor
    func testClassicAndDailyGamesSurviveRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetStore"]
        app.launch()

        // Classic: change the board, leave, relaunch, continue.
        app.buttons["New Game"].tap()
        app.buttons["Add numbers"].tap()
        XCTAssertTrue(app.buttons["cell-27"].waitForExistence(timeout: 2))
        let classicCells = app.buttons.matching(identifierPrefix: "cell-").count

        // Daily: start today's challenge and change it too.
        app.navigationBars.buttons.element(boundBy: 0).tap()
        dailyCard(app).tap()
        app.buttons["Play"].tap()
        XCTAssertTrue(app.staticTexts["Daily Challenge"].waitForExistence(timeout: 2))
        app.buttons["Add numbers"].tap()
        let dailyCells = app.buttons.matching(identifierPrefix: "cell-").count

        app.terminate()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        XCTAssertTrue(dailyCard(app).label.contains("In progress"))
        snapshot(app, "home")
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.buttons["cell-27"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons.matching(identifierPrefix: "cell-").count, classicCells)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        dailyCard(app).tap()
        snapshot(app, "daily")
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["Daily Challenge"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons.matching(identifierPrefix: "cell-").count, dailyCells)
        snapshot(app, "daily-resumed")
    }

    @MainActor
    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    private func dailyCard(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Daily Challenge'")).firstMatch
    }
}

private extension XCUIElementQuery {
    func matching(identifierPrefix prefix: String) -> XCUIElementQuery {
        matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
    }
}
