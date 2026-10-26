import XCTest

/// Plays a few moves on a known board. `-seedKey 2026-10-25` produces:
///   5 9 3 7 6 3 8 4 5
///   9 9 3 3 1 7 8 9 6
///   9 1 9 5 3 5 1 3 6
final class GameplayUITests: XCTestCase {
    @MainActor
    func testMatchingAndAddingNumbers() {
        let app = XCUIApplication()
        app.launchArguments = ["-startGame", "-seedKey", "2026-10-25"]
        app.launch()

        let score = app.staticTexts["score"]
        XCTAssertTrue(score.waitForExistence(timeout: 5))

        // 3 + 7, adjacent.
        app.buttons["cell-2"].tap()
        app.buttons["cell-3"].tap()
        XCTAssertEqual(score.value as? String, "1")
        snapshot(app, "match")

        // 5 and 9: invalid, selection moves to the 9.
        app.buttons["cell-0"].tap()
        app.buttons["cell-1"].tap()
        XCTAssertEqual(score.value as? String, "1")

        // 9 above 9, vertical.
        app.buttons["cell-10"].tap()
        XCTAssertEqual(score.value as? String, "2")

        // Hint costs 3 but the score floors at 0.
        app.buttons["Hint"].tap()
        XCTAssertEqual(score.value as? String, "0")
        snapshot(app, "hint")

        app.buttons["Add numbers"].tap()
        XCTAssertTrue(app.buttons["cell-27"].waitForExistence(timeout: 2))

        snapshot(app, "added")
    }

    @MainActor
    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
