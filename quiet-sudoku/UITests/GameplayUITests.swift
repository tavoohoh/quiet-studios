import XCTest

/// Plays the real app: hints, notes, a win, and the tutorial from start to end.
final class GameplayUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments + ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        return app
    }

    func testHintExplainsAndScores() {
        let app = launch(["-startGame", "-seedKey", "ui-hint", "-level", "1"])
        XCTAssertTrue(app.buttons["hint"].waitForExistence(timeout: 10))
        app.buttons["hint"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["hintCard"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.staticTexts["score"].label, "Score -10")
    }

    func testNotesGoInTheSelectedCell() {
        let app = launch(["-startGame", "-seedKey", "ui-notes"])
        XCTAssertTrue(app.buttons["notes"].waitForExistence(timeout: 10))
        // An empty cell: its label says so.
        let empty = app.buttons.matching(NSPredicate(format: "label ENDSWITH 'empty'")).firstMatch
        empty.tap()
        app.buttons["notes"].tap()
        app.buttons["digit-3"].tap()
        app.buttons["digit-7"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'notes 3 and 7'")).firstMatch.exists)
    }

    func testLastDigitWins() {
        let app = launch(["-startGame", "-seedKey", "ui-win", "-nearlyWon"])
        XCTAssertTrue(app.buttons["hint"].waitForExistence(timeout: 10))
        let empty = app.buttons.matching(NSPredicate(format: "label ENDSWITH 'empty'")).firstMatch
        empty.tap()
        // Try digits until the right one: wrong ones stay red and get replaced.
        for digit in 1...9 where !app.staticTexts["Solved!"].exists {
            app.buttons["digit-\(digit)"].tap()
        }
        XCTAssertTrue(app.staticTexts["Solved!"].waitForExistence(timeout: 6))
    }

    func testTutorialFromScratch() {
        let app = launch(["-uiTesting", "-resetStore", "-tutorial"])
        app.buttons["newGame"].tap()
        XCTAssertTrue(app.buttons["skipTutorial"].waitForExistence(timeout: 5))
        for step in 1...7 {
            XCTAssertTrue(app.staticTexts["Step \(step) of 7"].waitForExistence(timeout: 5), "step \(step)")
            if app.buttons["hint"].exists {
                app.buttons["hint"].tap()
            } else {
                // Only the right answers count: the others are refused without cost.
                for digit in 1...9 where app.staticTexts["Step \(step) of 7"].exists {
                    app.buttons["digit-\(digit)"].tap()
                }
            }
        }
        XCTAssertTrue(app.buttons["finishTutorial"].waitForExistence(timeout: 8))
        app.buttons["finishTutorial"].tap()
        XCTAssertTrue(app.buttons["hint"].waitForExistence(timeout: 10))
    }
}
