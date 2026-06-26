import XCTest

final class ConferenceManagementUITests: XCTestCase {
    func testFirstLaunchOnboardingShowsFiltersAndDisabledContinue() {
        let app = launch(seedScenario: "empty")

        XCTAssertTrue(app.buttons["topconf.onboarding.continue"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["topconf.onboarding.continue"].isEnabled)
        XCTAssertTrue(app.buttons["topconf.filter.category.ai"].exists)
        XCTAssertTrue(app.buttons["topconf.filter.category.graphics"].exists)
        XCTAssertTrue(app.buttons["topconf.filter.category.hci"].exists)
        XCTAssertTrue(app.buttons["topconf.filter.category.interdisciplinary"].exists)
        XCTAssertTrue(app.buttons["topconf.filter.rank.a"].exists)

        let search = app.textFields["topconf.search.discovery"]
        XCTAssertTrue(search.exists)
    }

    func testNineTrackedLaunchShowsManagement() {
        let app = launch(seedScenario: "nineTracked", initialSearchQuery: "AAAI")

        XCTAssertTrue(element("topconf.tracked.table", in: app).waitForExistence(timeout: 5))
        XCTAssertEqual(trackedRowCount(in: app), 9)
        XCTAssertTrue(app.staticTexts["TopConf"].exists)
        XCTAssertFalse(app.buttons["topconf.onboarding.continue"].exists)
    }

    func testInitialSearchQueryLaunchesConferenceManagement() {
        let app = launch(seedScenario: "empty", initialSearchQuery: "SIGIR")

        XCTAssertTrue(app.staticTexts["Choose Conferences"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["topconf.search.discovery"].exists)
    }

    func testTenTrackedLaunchShowsManagementAndTrackedColumn() {
        let app = launch(seedScenario: "tenTracked", initialSearchQuery: "KDD")

        XCTAssertTrue(app.staticTexts["TopConf"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["topconf.onboarding.continue"].exists)
    }

    func testTrackingLimitBlocksEleventhAndRemovalRestoresAddCapability() {
        let app = launch(seedScenario: "tenTracked", initialSearchQuery: "NeurIPS")

        XCTAssertTrue(app.buttons["topconf.tracked.manage"].waitForExistence(timeout: 5))
        app.buttons["topconf.tracked.manage"].click()
        XCTAssertTrue(element("topconf.management.available", in: app).waitForExistence(timeout: 5))

        let blockedAdd = app.buttons["topconf.add.ai-neurips"]
        XCTAssertTrue(blockedAdd.waitForExistence(timeout: 5))
        XCTAssertFalse(blockedAdd.isEnabled)
        XCTAssertTrue(app.staticTexts["10 / 10"].firstMatch.waitForExistence(timeout: 5))

        let removeTracked = app.buttons["topconf.tracked.remove.ai-aaai"]
        XCTAssertTrue(removeTracked.waitForExistence(timeout: 5))
        removeTracked.click()

        XCTAssertTrue(waitForEnabled(blockedAdd))
        XCTAssertTrue(app.staticTexts["9 / 10"].firstMatch.waitForExistence(timeout: 5))
        blockedAdd.click()
        XCTAssertTrue(app.staticTexts["10 / 10"].firstMatch.waitForExistence(timeout: 5))
    }

    private func launch(seedScenario: String, initialSearchQuery: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-UITesting",
            "-ResetStore",
            "-SeedScenario",
            seedScenario
        ]
        if let initialSearchQuery {
            app.launchArguments += [
                "-InitialSearchQuery",
                initialSearchQuery
            ]
        }
        app.launchEnvironment["TOPCONF_UI_TESTING"] = "1"
        app.launchEnvironment["AppleLanguages"] = "(en)"
        app.launchEnvironment["AppleLocale"] = "en_US"
        app.launch()
        app.activate()
        return app
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func trackedRowCount(in app: XCUIApplication) -> Int {
        let rowMarkers = app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "topconf.tracked.abbreviation."))
        _ = rowMarkers.firstMatch.waitForExistence(timeout: 5)
        return rowMarkers.count
    }

    private func waitForEnabled(_ element: XCUIElement) -> Bool {
        let predicate = NSPredicate(format: "isEnabled == true")
        return XCTWaiter.wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: 5) == .completed
    }
}
