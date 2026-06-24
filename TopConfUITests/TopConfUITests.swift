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
}
