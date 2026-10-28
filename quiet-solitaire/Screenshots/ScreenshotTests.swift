import XCTest

/// App Store screenshots from the deterministic `-demo` state (see `DemoData`).
/// Run through `scripts/screenshots.sh`, which picks the device, language and appearance.
/// Language comes from `QS_LANGUAGE` (`en`, `es`), passed as `TEST_RUNNER_QS_LANGUAGE`.
final class ScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func testScreenshots() {
        let app = launch()

        // 1. A game in progress.
        tap(app.buttons["continue"])
        XCTAssertTrue(app.staticTexts["score"].waitForExistence(timeout: 5))
        sleep(1)
        capture(app, "01-game")
        goBack(app)

        // 2. Daily challenge: streak, week difficulty, calendar.
        tap(app.buttons["daily"])
        sleep(1)
        capture(app, "02-daily")
        goBack(app)

        // 3. Leaderboards, Friends.
        tap(app.buttons["leaderboards"])
        tap(app.buttons[language == "es" ? "Amigos" : "Friends"])
        sleep(1)
        capture(app, "03-leaderboards")
        goBack(app)

        // 4. Collection.
        tap(app.buttons["collection"])
        sleep(1)
        capture(app, "04-collection")
        app.terminate()

        // 5. The same game with unlocked rewards: Indigo board, Pixel deck, Night back.
        let themed = launch(extra: ["-board", "indigoPeach", "-deck", "pixel", "-back", "night"])
        tap(themed.buttons["continue"])
        XCTAssertTrue(themed.staticTexts["score"].waitForExistence(timeout: 5))
        sleep(1)
        capture(themed, "05-rewards")
        themed.terminate()
    }

    /// A win under 3 minutes (×2.0), mid-fireworks, with the win sheet.
    @MainActor
    func testWin() {
        let app = XCUIApplication()
        let locale = language == "es" ? "es_MX" : "en_US"
        app.launchArguments = ["-startGame", "-nearlyWon", "-demoClock", "170", "-AppleLanguages", "(\(language))", "-AppleLocale", locale]
        app.launch()
        let waste = app.descendants(matching: .any).matching(NSPredicate(format: "label ENDSWITH %@", language == "es" ? ", descarte" : ", waste")).firstMatch
        tap(waste)
        tap(app.buttons["autoComplete"])
        // No element queries from here: XCUITest waits for the app to be idle first, and the
        // fireworks keep it busy until they're over. 17 cards × 90 ms, then 1.4 s to the sheet
        // (the iPad simulator is slower); the last rockets burst around 5 s.
        sleep(5)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "06-win"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private var language: String { ProcessInfo.processInfo.environment["QS_LANGUAGE"] ?? "en" }

    @MainActor
    private func launch(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        let locale = language == "es" ? "es_MX" : "en_US"
        app.launchArguments = ["-demo", "-AppleLanguages", "(\(language))", "-AppleLocale", locale] + extra
        app.launch()
        return app
    }

    @MainActor
    private func tap(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing \(element)")
        element.tap()
    }

    @MainActor
    private func goBack(_ app: XCUIApplication) {
        app.buttons["back"].tap()
        sleep(1)
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
