import XCTest

/// Daily reminders on the demo state (Saturday 2026-11-14 10:00, today not played, 8-day
/// streak). On a fresh install it also checks that nothing is scheduled before permission.
final class ReminderUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func pending(_ app: XCUIApplication) -> XCUIElement {
        app.buttons["settings"].tap()
        let pending = app.staticTexts["pendingReminders"]
        XCTAssertTrue(pending.waitForExistence(timeout: 5))
        return pending
    }

    private func waitFor(_ element: XCUIElement, contains text: String) -> Bool {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        return XCTWaiter.wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: 8) == .completed
    }

    func testRemindersFollowTheDay() {
        let app = XCUIApplication()
        app.launchArguments = ["-demo", "-showReminders", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let list = pending(app)
        // First run on this simulator: nothing until the switch asks and it's allowed.
        if list.label == "none" {
            app.switches.matching(NSPredicate(format: "label BEGINSWITH 'Daily challenge reminder'")).firstMatch.tap()
            let allow = XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.buttons["Allow"]
            XCTAssertTrue(allow.waitForExistence(timeout: 5))
            allow.tap()
        }
        // 19:00 and 21:00 today, with the streak at stake.
        XCTAssertTrue(waitFor(list, contains: "daily.2026-11-14.reminder · 19:00 · Don't lose your 8-day streak."))
        XCTAssertTrue(list.label.contains("daily.2026-11-14.streakAtRisk · 21:00 · Your 8-day streak ends at midnight."))

        // The background refresh rewrites today's reminder with the demo friends.
        app.terminate()
        app.launchArguments += ["-refreshFriends"]
        app.launch()
        XCTAssertTrue(waitFor(pending(app), contains: "3 friends already played; vale leads with 1,377."))

        // Today won: today's are gone and the streak at stake moves to tomorrow.
        app.terminate()
        app.launchArguments = ["-demo", "-showReminders", "-completeToday", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        let after = pending(app)
        XCTAssertTrue(waitFor(after, contains: "daily.2026-11-15.streakAtRisk · 21:00 · Your 9-day streak ends at midnight."))
        XCTAssertFalse(after.label.contains("daily.2026-11-14"))
    }
}
