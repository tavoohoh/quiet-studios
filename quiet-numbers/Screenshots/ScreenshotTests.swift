import XCTest

/// App Store screenshots from the deterministic `-demo` state (see `DemoData`).
/// Run through `scripts/screenshots.sh`, which picks the device, language and appearance.
/// Language comes from `QN_LANGUAGE` (`en`, `es`) and, on Mac, appearance from `QN_APPEARANCE`;
/// the script passes them as `TEST_RUNNER_QN_…` so they reach the test runner.
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
        capture(app, "01-game")
        goBack(app)

        // 2. Daily challenge with streak and calendar.
        tap(app.buttons["daily"])
        sleep(1)
        capture(app, "02-daily")
        goBack(app)

        // 3. Leaderboards.
        tap(app.buttons["leaderboards"])
        sleep(1)
        capture(app, "03-leaderboards")
        goBack(app)

        // 4. Collection of rewards.
        tap(app.buttons["collection"])
        sleep(1)
        capture(app, "04-collection")
        app.terminate()

        // 5. The same game with an unlocked theme.
        let themed = launch(extra: ["-theme", "midnight"])
        tap(themed.buttons["continue"])
        XCTAssertTrue(themed.staticTexts["score"].waitForExistence(timeout: 5))
        capture(themed, "05-theme")
    }

    @MainActor
    private func launch(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        let language = ProcessInfo.processInfo.environment["QN_LANGUAGE"] ?? "en"
        let locale = language == "es" ? "es_MX" : "en_US"
        app.launchArguments = ["-demo", "-AppleLanguages", "(\(language))", "-AppleLocale", locale, "-ApplePersistenceIgnoreState", "YES"] + extra
        #if os(macOS)
        // Simulators get their appearance from the script; the Mac app is told directly.
        if ProcessInfo.processInfo.environment["QN_APPEARANCE"] == "dark" {
            app.launchArguments += ["-AppleInterfaceStyle", "Dark"]
        }
        #endif
        app.launch()
        #if os(macOS)
        app.activate()
        _ = app.windows.firstMatch.waitForExistence(timeout: 10)
        #endif
        return app
    }

    @MainActor
    private func tap(_ element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Missing \(element)")
        #if os(macOS)
        element.click()
        #else
        element.tap()
        #endif
    }

    @MainActor
    private func goBack(_ app: XCUIApplication) {
        #if os(macOS)
        app.typeKey("[", modifierFlags: .command)
        #else
        app.navigationBars.buttons.element(boundBy: 0).tap()
        #endif
        sleep(1)
    }

    @MainActor
    private func capture(_ app: XCUIApplication, _ name: String) {
        #if os(macOS)
        let screenshot = app.windows.firstMatch.screenshot()
        #else
        let screenshot = app.screenshot()
        #endif
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
