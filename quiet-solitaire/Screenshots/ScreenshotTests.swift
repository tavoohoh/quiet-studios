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

    /// Every screen in English, for the design canvas's "Screens" page (`scripts/design-screens.sh`).
    @MainActor
    func testDesignScreens() {
        let app = launch()
        capture(app, "01-home")
        tap(app.buttons["continue"])
        XCTAssertTrue(app.staticTexts["score"].waitForExistence(timeout: 5))
        sleep(1)
        capture(app, "02-game")
        goBack(app)
        tap(app.buttons["daily"])
        sleep(1)
        capture(app, "04-daily")
        goBack(app)
        tap(app.buttons["leaderboards"])
        sleep(1)
        capture(app, "05-leaderboards")
        goBack(app)
        tap(app.buttons["collection"])
        sleep(1)
        capture(app, "06-collection")
        goBack(app)
        tap(app.buttons["settings"])
        sleep(1)
        capture(app, "07-settings")
        app.terminate()

        // The same game in each unlockable deck, for the canvas's components.
        for deck in ["illustrated", "classic", "pixel"] {
            let themed = launch(extra: ["-unlockAll", "-deck", deck])
            tap(themed.buttons["continue"])
            XCTAssertTrue(themed.staticTexts["score"].waitForExistence(timeout: 5))
            sleep(1)
            capture(themed, "09-deck-\(deck)")
            themed.terminate()
        }

        // The "no way out" notice over a lost deal.
        let lost = XCUIApplication()
        lost.launchArguments = ["-startGame", "-lostDeal", "-AppleLanguages", "(\(language))", "-AppleLocale", "en_US"]
        lost.launch()
        XCTAssertTrue(lost.buttons["keepPlaying"].waitForExistence(timeout: 10))
        sleep(1)
        capture(lost, "08-stuck")
        lost.terminate()

        // The win sheet, after the fireworks (see testWin).
        let win = XCUIApplication()
        win.launchArguments = ["-startGame", "-nearlyWon", "-demoClock", "170", "-AppleLanguages", "(\(language))", "-AppleLocale", "en_US"]
        win.launch()
        let waste = win.descendants(matching: .any).matching(NSPredicate(format: "label ENDSWITH %@", ", waste")).firstMatch
        tap(waste)
        tap(win.buttons["autoComplete"])
        sleep(7)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "03-summary"
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
