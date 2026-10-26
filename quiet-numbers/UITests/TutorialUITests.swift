import XCTest

/// The tutorial comes before the first game, takes only the guided moves, and ends in a game.
final class TutorialUITests: XCTestCase {
    @MainActor
    func testTutorialBeforeFirstGame() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetStore", "-tutorial"]
        app.launch()
        app.buttons["New Game"].tap()
        XCTAssertTrue(app.staticTexts["Step 1 of 7"].waitForExistence(timeout: 3))

        // A move that isn't the guided one doesn't count.
        app.buttons["cell-0"].tap()
        app.buttons["cell-1"].tap()
        XCTAssertTrue(app.staticTexts["Step 1 of 7"].exists)

        // Step 1 by dragging from one 5 to the other.
        app.buttons["cell-10"].press(forDuration: 0.1, thenDragTo: app.buttons["cell-11"])
        // Steps 2–6 by tapping; cell ids are board positions.
        let pairs = [(12, 21), (13, 3), (9, 14), (17, 18), (15, 16)]
        for (step, pair) in zip(2..., pairs) {
            XCTAssertTrue(app.staticTexts["Step \(step) of 7"].waitForExistence(timeout: 3), "step \(step)")
            if step == 4 { snapshot(app, "tutorial-long-shot") }
            app.buttons["cell-\(pair.0)"].tap()
            app.buttons["cell-\(pair.1)"].tap()
        }
        XCTAssertTrue(app.staticTexts["Step 7 of 7"].waitForExistence(timeout: 3))
        app.buttons["Add numbers"].tap()

        let finish = app.buttons["finishTutorial"]
        XCTAssertTrue(finish.waitForExistence(timeout: 3))
        snapshot(app, "tutorial-done")
        finish.tap()
        XCTAssertTrue(app.staticTexts["score"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Step 7 of 7"].exists)

        // Seen once: the next New Game goes straight in.
        app.buttons["back"].tap()
        app.buttons["New Game"].tap()
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["skipTutorial"].exists)
    }

    @MainActor
    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
