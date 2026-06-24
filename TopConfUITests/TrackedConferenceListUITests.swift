import XCTest

final class TrackedConferenceListUITests: XCTestCase {
    func testZeroTrackedShowsEmptyStateAndChooseConferencesOpensManagement() {
        let app = launch(seedScenario: "zeroTracked")

        XCTAssertTrue(element("topconf.empty.noTracked", in: app).waitForExistence(timeout: 5))
        app.buttons["topconf.tracked.manage"].firstMatch.click()
        XCTAssertTrue(element("topconf.management.available", in: app).waitForExistence(timeout: 5))
    }

    func testOneTrackedConferenceAppearsWithDeadlinePresentationAndWebsiteAction() {
        let app = launch(seedScenario: "oneUpcoming")

        XCTAssertTrue(element("topconf.tracked.table", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(rowMarker("hci-chi", in: app).exists)
        XCTAssertTrue(app.staticTexts["topconf.tracked.remaining.hci-chi"].exists)
        XCTAssertTrue(app.staticTexts["topconf.tracked.originalDeadline.hci-chi"].exists)
        XCTAssertTrue(app.staticTexts["topconf.tracked.beijingTime.hci-chi"].exists)
        XCTAssertTrue(app.links["topconf.tracked.website.hci-chi"].exists || app.buttons["topconf.tracked.website.hci-chi"].exists)
    }

    func testMultipleTrackedConferencesAreSortedAcrossCategories() {
        let app = launch(seedScenario: "multipleSorted")

        XCTAssertTrue(element("topconf.tracked.table", in: app).waitForExistence(timeout: 5))
        assertRow("interdisciplinary-kdd", isAbove: "interdisciplinary-sigir", in: app)
        assertRow("interdisciplinary-sigir", isAbove: "hci-chi", in: app)
        assertRow("hci-chi", isAbove: "ai-aaai", in: app)
        assertRow("ai-aaai", isAbove: "ai-aamas", in: app)
        assertRow("ai-neurips", isAbove: "graphics-siggraph", in: app)
        assertRow("graphics-siggraph", isAbove: "graphics-acm-mm", in: app)
    }

    func testTBDClosedAndSourceUnavailableAreShown() {
        let tbdAndClosed = launch(seedScenario: "tbdAndClosed")
        XCTAssertTrue(rowMarker("graphics-siggraph", in: tbdAndClosed).waitForExistence(timeout: 5))
        XCTAssertTrue(tbdAndClosed.staticTexts["topconf.tracked.status.graphics-siggraph"].exists)
        XCTAssertTrue(tbdAndClosed.staticTexts["topconf.tracked.status.graphics-acm-mm"].exists)

        let unavailable = launch(seedScenario: "sourceUnavailable")
        XCTAssertTrue(rowMarker("missing-source-conf", in: unavailable).waitForExistence(timeout: 5))
        XCTAssertTrue(unavailable.staticTexts["topconf.tracked.status.missing-source-conf"].exists)
    }

    func testTrackedSearchFiltersAndClearingRestoresRows() {
        let app = launch(seedScenario: "multipleSorted")
        XCTAssertTrue(rowMarker("hci-chi", in: app).waitForExistence(timeout: 5))

        let search = app.textFields["topconf.search.tracked"]
        search.click()
        search.typeText("CHI")
        search.typeKey(.return, modifierFlags: [])

        XCTAssertTrue(rowMarker("hci-chi", in: app).exists)
        XCTAssertTrue(waitForAbsence(rowMarker("ai-neurips", in: app)))

        app.buttons["topconf.search.tracked.clear"].click()

        XCTAssertTrue(rowMarker("ai-neurips", in: app).waitForExistence(timeout: 5))
    }

    func testMainListDoesNotDisplayUntrackedCatalogConferencesAndTenTrackedCanAppear() {
        let app = launch(seedScenario: "tenTracked")

        XCTAssertTrue(element("topconf.tracked.table", in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(rowMarker("interdisciplinary-wsdm", in: app).exists)
        XCTAssertEqual(trackedRowCount(in: app), 10)
    }

    func testManageConferencesIsAvailableAndNoCategoryOrRankGroupingIsApplied() {
        let app = launch(seedScenario: "multipleSorted")

        XCTAssertTrue(app.buttons["topconf.tracked.manage"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["CCF-A"].exists)
        XCTAssertFalse(app.staticTexts["Artificial Intelligence"].exists)
    }

    private func launch(seedScenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-UITesting",
            "-ResetStore",
            "-SeedScenario",
            seedScenario
        ]
        app.launchEnvironment["TOPCONF_UI_TESTING"] = "1"
        app.launchEnvironment["AppleLanguages"] = "(en)"
        app.launchEnvironment["AppleLocale"] = "en_US"
        app.launch()
        app.activate()
        return app
    }

    private func assertRow(_ firstID: String, isAbove secondID: String, in app: XCUIApplication) {
        let first = rowMarker(firstID, in: app)
        let second = rowMarker(secondID, in: app)

        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertTrue(second.waitForExistence(timeout: 5))
        XCTAssertLessThan(first.frame.minY, second.frame.minY)
    }

    private func trackedRowCount(in app: XCUIApplication) -> Int {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", "topconf.tracked.abbreviation."))
            .count
    }

    private func rowMarker(_ conferenceID: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts["topconf.tracked.abbreviation.\(conferenceID)"].firstMatch
    }

    private func element(_ identifier: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func waitForAbsence(_ element: XCUIElement) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        return XCTWaiter.wait(for: [expectation(for: predicate, evaluatedWith: element)], timeout: 5) == .completed
    }
}
