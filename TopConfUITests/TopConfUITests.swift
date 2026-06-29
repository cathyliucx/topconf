import XCTest

final class TopConfUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-UITesting",
            "-SeedScenario",
            "empty"
        ]
        app.launchEnvironment["TOPCONF_UI_TESTING"] = "1"
        app.launch()

        XCTAssertTrue(app.staticTexts["TopConf"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["topconf.onboarding.continue"].exists)
    }

    func testLauncherPanelClosesWithEscape() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-UITesting",
            "-SeedScenario",
            "oneUpcoming"
        ]
        app.launchEnvironment["TOPCONF_UI_TESTING"] = "1"
        app.launch()
        app.activate()

        let panel = app.descendants(matching: .any)
            .matching(identifier: "topconf.launcher.panel")
            .firstMatch
        XCTAssertTrue(panel.waitForExistence(timeout: 5))

        app.typeKey(.escape, modifierFlags: [])

        let closed = XCTWaiter.wait(
            for: [expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: panel)],
            timeout: 5
        )
        XCTAssertEqual(closed, .completed)
    }

    func testLauncherSupportsLightAndDarkAppearances() throws {
        for appearance in ["light", "dark"] {
            let app = XCUIApplication()
            app.launchArguments = [
                "-UITesting",
                "-ResetStore",
                "-SeedScenario",
                "oneUpcoming",
                "-Appearance",
                appearance
            ]
            app.launchEnvironment["TOPCONF_UI_TESTING"] = "1"
            app.launchEnvironment["AppleLanguages"] = "(en)"
            app.launchEnvironment["AppleLocale"] = "en_US"
            app.launch()
            app.activate()

            XCTAssertTrue(element("topconf.launcher.panel", in: app).exists)
            XCTAssertTrue(element("topconf.tracked.table", in: app).waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts["topconf.tracked.abbreviation.ai-iclr"].exists)

            app.terminate()
        }
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
}
