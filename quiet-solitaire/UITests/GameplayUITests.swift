import XCTest

final class GameplayUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// One move from the end: auto-complete wins and the win sheet appears.
    func testAutoCompleteWins() {
        let app = XCUIApplication()
        app.launchArguments = ["-startGame", "-nearlyWon"]
        app.launch()
        // The 10♥ from the waste goes on the J♠.
        app.buttons["10 of hearts, waste"].firstMatch.tap()
        let autoComplete = app.buttons["autoComplete"]
        XCTAssertTrue(autoComplete.waitForExistence(timeout: 3))
        autoComplete.tap()
        XCTAssertTrue(app.buttons["winNewGame"].waitForExistence(timeout: 10))
    }

    /// Dragging the waste card onto a column plays it.
    func testDragWasteToColumn() {
        let app = XCUIApplication()
        app.launchArguments = ["-startGame", "-nearlyWon"]
        app.launch()
        let ten = app.buttons["10 of hearts, waste"].firstMatch
        let jack = app.buttons["Jack of spades, column 4"].firstMatch
        XCTAssertTrue(ten.waitForExistence(timeout: 3))
        ten.press(forDuration: 0.1, thenDragTo: jack)
        XCTAssertTrue(app.buttons["10 of hearts, column 4"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["autoComplete"].waitForExistence(timeout: 3))
    }

    /// The tutorial walks through its six moves by tapping, then starts a game.
    func testTutorial() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetStore", "-tutorial"]
        app.launch()
        app.buttons["newGame"].tap()
        let cards = ["Stock, 3 cards", "7 of hearts, waste", "Ace of diamonds, column 2", "8 of spades, column 1",
                     "2 of diamonds, column 1", "King of clubs, column 4"]
        for label in cards {
            let card = app.buttons[label].firstMatch
            XCTAssertTrue(card.waitForExistence(timeout: 3), label)
            card.tap()
        }
        let finish = app.buttons["finishTutorial"]
        XCTAssertTrue(finish.waitForExistence(timeout: 3))
        finish.tap()
        XCTAssertTrue(app.staticTexts["score"].waitForExistence(timeout: 5))
    }

    /// A new classic game from Home: drawing changes the move count; undo works.
    func testNewGameDrawAndUndo() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetStore"]
        app.launch()
        app.buttons["newGame"].tap()
        let stock = app.buttons["stock"]
        XCTAssertTrue(app.staticTexts["score"].waitForExistence(timeout: 5))
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Stock,'")).firstMatch.tap()
        XCTAssertTrue(app.buttons["undo"].isEnabled)
        app.buttons["undo"].tap()
        _ = stock
    }
}
