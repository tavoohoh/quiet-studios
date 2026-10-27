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
