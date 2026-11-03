import XCTest

/// Bug of 2026-11-02: start a daily, start over, play differently, leave the app and come
/// back: the first attempt came back instead of the latest one.
final class DailyRestartUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testStartingOverAPastDayKeepsTheLatestAttempt() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-resetStore", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        // First attempt: one +.
        openPastDay(app)
        app.buttons["Add numbers"].tap()
        let first = cellCount(app)
        app.buttons["back"].tap()

        // Start over and play differently: two +.
        pastDay(app).tap()
        app.alerts.buttons["Start over"].tap()
        XCTAssertTrue(app.staticTexts["score"].waitForExistence(timeout: 2))
        app.buttons["Add numbers"].tap()
        app.buttons["Add numbers"].tap()
        let latest = cellCount(app)
        XCTAssertNotEqual(first, latest)

        // Leave the app and come back.
        app.terminate()
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        dailyCard(app).tap()
        pastDay(app).tap()
        app.alerts.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["score"].waitForExistence(timeout: 2))
        XCTAssertEqual(cellCount(app), latest)
    }

    /// The day before today, a month back on the 1st.
    private var pastDayKey: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Calendar.current.date(byAdding: .day, value: -1, to: .now)!)
    }

    @MainActor
    private func pastDay(_ app: XCUIApplication) -> XCUIElement {
        let day = app.buttons["day-\(pastDayKey)"]
        if !day.waitForExistence(timeout: 2) { app.buttons["Previous month"].tap() }
        XCTAssertTrue(day.waitForExistence(timeout: 2))
        return day
    }

    @MainActor
    private func openPastDay(_ app: XCUIApplication) {
        dailyCard(app).tap()
        pastDay(app).tap()
        XCTAssertTrue(app.staticTexts["score"].waitForExistence(timeout: 2))
    }

    @MainActor
    private func cellCount(_ app: XCUIApplication) -> Int {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cell-'")).count
    }

    @MainActor
    private func dailyCard(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Daily Challenge'")).firstMatch
    }
}
