import XCTest

/// App Store screenshots from the deterministic `-demo` state (see `DemoData`).
/// Run through `scripts/screenshots.sh`, which picks the device, language and appearance.
/// Language comes from `QN_LANGUAGE` (`en`, `es`); the script passes it as `TEST_RUNNER_QN_LANGUAGE`
/// so it reaches the test runner. Appearance is set on the simulator.
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
        let themed = launch(extra: ["-theme", "indigoPeach"])
        tap(themed.buttons["continue"])
        XCTAssertTrue(themed.staticTexts["score"].waitForExistence(timeout: 5))
        capture(themed, "05-theme")
        themed.terminate()

        // 6. Leaderboards with Friends selected (App Store image 5).
        let friends = launch()
        tap(friends.buttons["leaderboards"])
        tap(friends.buttons[language == "es" ? "Amigos" : "Friends"])
        sleep(1)
        capture(friends, "06-leaderboards-friends")
    }

    /// The canvas's hand-made board (`DemoData.StoreScene`) for App Store images 1, 2 and 4,
    /// plus where its first and last cells and the score are (points), so the frames can place their callouts.
    @MainActor
    func testStoreScenes() throws {
        for scene in ["1", "2", "4"] {
            let app = launch(extra: ["-storeScene", scene])
            tap(app.buttons["continue"])
            XCTAssertTrue(app.staticTexts["score"].waitForExistence(timeout: 5))
            sleep(1)
            capture(app, "store\(scene)")
            let first = app.descendants(matching: .any)["cell-0"].frame
            let last = app.descendants(matching: .any)["cell-89"].frame
            let score = app.staticTexts["score"].frame
            let geometry = [first.midX, first.midY, last.midX, last.midY, score.minX, score.minY]
            let attachment = XCTAttachment(string: geometry.map { "\($0)" }.joined(separator: ","))
            attachment.name = "store\(scene)-cells"
            attachment.lifetime = .keepAlways
            add(attachment)
            app.terminate()
        }
    }

    private var language: String { ProcessInfo.processInfo.environment["QN_LANGUAGE"] ?? "en" }

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
