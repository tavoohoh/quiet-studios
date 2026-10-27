import XCTest

/// Plays a few moves on a known board. `-seedKey 2026-10-25` produces:
///   8 4 3 4 9 8 5 1 1
///   1 1 8 4 6 4 3 5 7
///   9 1 2 7 9 6 9 8 9
///   4 1 4 1 4 6 6 4 4
///   7 2 4 7 9 9
final class GameplayUITests: XCTestCase {
    @MainActor
    func testMatchingAndAddingNumbers() {
        let app = XCUIApplication()
        app.launchArguments = ["-startGame", "-seedKey", "2026-10-25"]
        app.launch()

        let score = app.staticTexts["score"]
        XCTAssertTrue(score.waitForExistence(timeout: 5))

        // 1 and 1, adjacent.
        app.buttons["cell-7"].tap()
        app.buttons["cell-8"].tap()
        XCTAssertEqual(score.value as? String, "1")
        snapshot(app, "match")

        // 8 and 4: invalid, selection moves to the 4.
        app.buttons["cell-0"].tap()
        app.buttons["cell-3"].tap()
        XCTAssertEqual(score.value as? String, "1")

        // 4 above 4, vertical.
        app.buttons["cell-12"].tap()
        XCTAssertEqual(score.value as? String, "2")

        // Undo takes back exactly one move.
        app.buttons["Undo"].tap()
        XCTAssertEqual(score.value as? String, "1")
        XCTAssertFalse(app.buttons["Undo"].isEnabled)
        app.buttons["cell-3"].tap()
        app.buttons["cell-12"].tap()
        XCTAssertEqual(score.value as? String, "2")

        // Hint costs 10, even below zero.
        app.buttons["Hint"].tap()
        XCTAssertEqual(score.value as? String, "-8")
        snapshot(app, "hint")

        app.buttons["Add numbers"].tap()
        XCTAssertTrue(app.buttons["cell-50"].waitForExistence(timeout: 2))

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

/// Captures the match effects in slow motion on a hand-made board:
///   5 3 7 4 6 1 9 2 5
///   1 3 1 3 1 3 1 8 3
///   4 2 4 2 4 2 4 2 4
/// Clearing 3-7, 4-6, 1-9 and 2-8 leaves 5 … 5 across seven ghosts: a long shot that also empties row 1.
final class EffectsUITests: XCTestCase {
    @MainActor
    func testMatchEffects() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-startGame", "-slowEffects",
            "-boardValues", "5,3,7,4,6,1,9,2,5,1,3,1,3,1,3,1,8,3,4,2,4,2,4,2,4,2,4",
        ]
        app.launch()
        XCTAssertTrue(app.buttons["cell-0"].waitForExistence(timeout: 5))

        app.buttons["cell-1"].tap()
        app.buttons["cell-2"].tap()
        snapshot(app, "line-subtle")

        for (a, b) in [(3, 4), (5, 6), (7, 16)] {
            app.buttons["cell-\(a)"].tap()
            app.buttons["cell-\(b)"].tap()
        }
        sleep(4)

        app.buttons["cell-0"].tap()
        app.buttons["cell-8"].tap()
        snapshot(app, "line-dramatic")
        usleep(700_000)
        snapshot(app, "pop")
        usleep(1_200_000)
        snapshot(app, "points-and-praise")
        sleep(2)
        snapshot(app, "row-effect")
        sleep(4)
        snapshot(app, "collapsed")

        app.buttons["Add numbers"].tap()
        sleep(3)
        snapshot(app, "added")
    }

    /// A hint with no pairs on the board points to + instead of charging.
    @MainActor
    func testEmptyHintSuggestsAddingNumbers() {
        let app = XCUIApplication()
        app.launchArguments = ["-startGame", "-boardValues", "1,2,1,2,1,2,1,2,1"]
        app.launch()
        XCTAssertTrue(app.buttons["Hint"].waitForExistence(timeout: 5))
        app.buttons["Hint"].tap()
        XCTAssertTrue(app.staticTexts["No pairs. Try +"].waitForExistence(timeout: 1))
        snapshot(app, "empty-hint")
    }

    @MainActor
    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
