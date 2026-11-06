import XCTest

/// Bug from 2026-11-02: in a daily, ⋯ › Restart This Deal, play differently, leave; back in,
/// "Continue" brought the FIRST attempt. Today and a past day, back from the game and after
/// relaunching the app (the store on disk reopened).
final class DailyRestartUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(reset: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + (reset ? ["-resetStore"] : [])
        app.launch()
        return app
    }

    private func moves(_ app: XCUIApplication) -> String {
        let moves = app.descendants(matching: .any)["moves"].firstMatch
        XCTAssertTrue(moves.waitForExistence(timeout: 5), app.debugDescription)
        return moves.label
    }

    private func draw(_ app: XCUIApplication, times: Int) {
        let stock = app.buttons["stock"].firstMatch
        // A past day is dealt on demand: the solver can take a few seconds.
        XCTAssertTrue(stock.waitForExistence(timeout: 30))
        for _ in 0..<times { stock.tap() }
    }

    /// Opens the day from the Daily Challenge screen; answers "Continue" if it asks.
    private func open(_ app: XCUIApplication, day: XCUIElement?) {
        let daily = app.buttons["daily"]
        if daily.waitForExistence(timeout: 2) { daily.tap() }
        if let day {
            // Yesterday can be in the previous month.
            if !day.waitForExistence(timeout: 3) { app.buttons["Previous month"].tap() }
            XCTAssertTrue(day.waitForExistence(timeout: 5))
            day.tap()
        } else {
            let play = app.buttons.matching(NSPredicate(format: "label IN %@", ["Play", "Continue", "Play again"])).firstMatch
            XCTAssertTrue(play.waitForExistence(timeout: 5))
            play.tap()
        }
        let resume = app.alerts.buttons["Continue"]
        if resume.waitForExistence(timeout: 3) { resume.tap() }
    }

    private func restartThisDeal(_ app: XCUIApplication) {
        app.buttons["More"].tap()
        let restart = app.buttons["Restart This Deal"]
        XCTAssertTrue(restart.waitForExistence(timeout: 3))
        restart.tap()
        // The menu's tap can be dropped under load; wait for the fresh deal before playing on.
        let moves = app.descendants(matching: .any)["moves"].firstMatch
        let reset = NSPredicate(format: "label ENDSWITH ', 0'")
        if XCTWaiter.wait(for: [expectation(for: reset, evaluatedWith: moves)], timeout: 3) != .completed {
            if restart.exists { restart.tap() } else { app.buttons["More"].tap(); restart.tap() }
            XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: reset, evaluatedWith: moves)], timeout: 5), .completed, moves.label)
        }
    }

    private func check(day: (XCUIApplication) -> XCUIElement?) {
        var app = launch(reset: true)
        open(app, day: day(app))
        draw(app, times: 3)
        restartThisDeal(app)
        draw(app, times: 1)
        let latest = moves(app)
        XCTAssertTrue(latest.contains("1"), latest)

        // Back to the Daily Challenge screen, and in again.
        app.buttons["back"].tap()
        open(app, day: day(app))
        XCTAssertEqual(moves(app), latest)

        // Relaunched.
        app.terminate()
        app = launch(reset: false)
        open(app, day: day(app))
        XCTAssertEqual(moves(app), latest)
    }

    func testTodayResumesTheLatestAttempt() {
        check { _ in nil }
    }

    func testPastDayResumesTheLatestAttempt() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.dateStyle = .long
        let label = formatter.string(from: yesterday)
        check { app in app.buttons[label].firstMatch }
    }
}
