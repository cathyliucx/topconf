import XCTest
@testable import TopConf

@MainActor
final class TrackedConferenceListViewModelTests: XCTestCase {
    func testInitialStateBeforeLoad() {
        let viewModel = makeViewModel(trackedIDs: [])

        XCTAssertEqual(viewModel.loadState, .idle)
        XCTAssertEqual(viewModel.rows, [])
        XCTAssertEqual(viewModel.visibleRows, [])
        XCTAssertEqual(viewModel.trackingCountText, "0 / 10")
    }

    func testSuccessfulLoadWithOneTrackedConference() async {
        let viewModel = makeViewModel(trackedIDs: ["hci-chi"])

        await viewModel.load()

        XCTAssertEqual(viewModel.loadState, .loaded)
        XCTAssertEqual(viewModel.rows.map(\.id), ["hci-chi"])
        XCTAssertEqual(viewModel.rows.first?.abbreviation, "CHI")
    }

    func testSuccessfulLoadWithMultipleTrackedConferences() async {
        let viewModel = makeViewModel(trackedIDs: ["ai-neurips", "hci-chi", "graphics-siggraph"])

        await viewModel.load()

        XCTAssertEqual(viewModel.rows.count, 3)
        XCTAssertEqual(viewModel.visibleRows.count, 3)
    }

    func testZeroTrackedConferencesLoadsEmptyState() async {
        let viewModel = makeViewModel(trackedIDs: [])

        await viewModel.load()

        XCTAssertTrue(viewModel.isEmpty)
        XCTAssertEqual(viewModel.rows, [])
    }

    func testRepeatedLoadDoesNotDuplicateRows() async {
        let viewModel = makeViewModel(trackedIDs: ["hci-chi", "ai-neurips"])

        await viewModel.load()
        await viewModel.load()

        XCTAssertEqual(viewModel.rows.map(\.id), ["hci-chi", "ai-neurips"])
    }

    func testLargeCatalogOnlyShowsTrackedConferences() async {
        let viewModel = makeViewModel(trackedIDs: ["hci-chi", "ai-neurips"])

        await viewModel.load()

        XCTAssertGreaterThan(SeedConferenceCatalog.conferences().count, TrackingPolicy.maximumConferenceCount)
        XCTAssertEqual(Set(viewModel.rows.map(\.id)), ["hci-chi", "ai-neurips"])
        XCTAssertFalse(viewModel.rows.contains { $0.id == "interdisciplinary-wsdm" })
    }

    func testTrackedListContainsAtMostTrackedLimitBecauseTrackedStateIsLimited() async {
        let trackedIDs = SeedConferenceCatalog.conferences()
            .prefix(TrackingPolicy.maximumConferenceCount)
            .map(\.id)
        let viewModel = makeViewModel(trackedIDs: Array(trackedIDs))

        await viewModel.load()

        XCTAssertGreaterThan(SeedConferenceCatalog.conferences().count, TrackingPolicy.maximumConferenceCount)
        XCTAssertEqual(viewModel.rows.count, TrackingPolicy.maximumConferenceCount)
    }

    func testNearestFutureDeadlineSelected() async {
        let viewModel = makeViewModel(trackedIDs: ["hci-chi"])

        await viewModel.load()

        XCTAssertEqual(viewModel.rows.first?.deadline.remainingText, "3 days")
        XCTAssertEqual(viewModel.rows.first?.deadline.typeText, "Paper")
    }

    func testMultipleDeadlinesSelectPaperWhenAbstractPassed() async {
        let viewModel = makeViewModel(trackedIDs: ["ai-iclr"])

        await viewModel.load()

        XCTAssertEqual(viewModel.rows.first?.deadline.typeText, "Paper")
        XCTAssertEqual(viewModel.rows.first?.deadline.remainingText, "10 days")
    }

    func testShuffledDeadlineOrderStillSelectsNearestFuture() async {
        let conference = customConference(
            id: "ai-shuffled",
            abbreviation: "SHUFFLED",
            deadlines: [
                customDeadline(id: "late", days: 20),
                customDeadline(id: "early", days: 2)
            ]
        )
        let viewModel = makeViewModel(conferences: [conference], trackedIDs: ["ai-shuffled"])

        await viewModel.load()

        XCTAssertEqual(viewModel.rows.first?.deadline.remainingText, "2 days")
    }

    func testMultipleEditionsAndLargerYearIsNotAutomaticallySelected() async {
        let conference = Conference(
            id: "ai-years",
            abbreviation: "YEARS",
            fullName: "Years Conference",
            category: SeedConferenceCatalog.ai,
            ccfRank: .a,
            websiteURL: nil,
            editions: [
                DomainTestFactory.edition(conferenceID: "ai-years", year: 2028, deadlines: [
                    DomainTestFactory.deadline(editionID: "ai-years-2028", date: DomainTestFactory.date(daysFromReference: -5))
                ]),
                DomainTestFactory.edition(conferenceID: "ai-years", year: 2026, deadlines: [
                    DomainTestFactory.deadline(editionID: "ai-years-2026", date: DomainTestFactory.date(daysFromReference: 4))
                ])
            ],
            lastUpdatedAt: nil
        )
        let viewModel = makeViewModel(conferences: [conference], trackedIDs: ["ai-years"])

        await viewModel.load()

        XCTAssertEqual(viewModel.rows.first?.editionYearText, "2026")
        XCTAssertEqual(viewModel.rows.first?.deadline.remainingText, "4 days")
    }

    func testTBDClosedAndSourceUnavailableStates() async {
        let viewModel = makeViewModel(trackedIDs: ["graphics-siggraph", "graphics-acm-mm", "missing-source-conf"])

        await viewModel.load()

        XCTAssertEqual(viewModel.rows.map(\.id), ["graphics-siggraph", "graphics-acm-mm", "missing-source-conf"])
        XCTAssertEqual(viewModel.rows[0].deadline.statusText, "TBD")
        XCTAssertEqual(viewModel.rows[1].deadline.statusText, "Closed")
        XCTAssertEqual(viewModel.rows[2].deadline.statusText, "Source unavailable")
    }

    func testLastKnownFallbackResolvesMissingCurrentCatalogConference() async {
        let cached = DomainTestFactory.conference(id: "cached-conf", abbreviation: "CACHE")
        let viewModel = makeViewModel(conferences: [], trackedIDs: ["cached-conf"], lastKnown: [cached])

        await viewModel.load()

        XCTAssertEqual(viewModel.rows.first?.abbreviation, "CACHE")
        XCTAssertEqual(viewModel.rows.first?.availability, .available)
    }

    func testSortingFutureTBDBeforeClosedBeforeUnavailable() async {
        let viewModel = makeViewModel(trackedIDs: [
            "missing-source-conf",
            "graphics-acm-mm",
            "graphics-siggraph",
            "hci-chi"
        ])

        await viewModel.load()

        XCTAssertEqual(viewModel.rows.map(\.id), [
            "hci-chi",
            "graphics-siggraph",
            "graphics-acm-mm",
            "missing-source-conf"
        ])
    }

    func testFutureDeadlinesSortAscendingAndEqualDeadlinesByAbbreviation() async {
        let viewModel = makeViewModel(trackedIDs: ["ai-neurips", "ai-aamas", "ai-aaai", "hci-chi"])

        await viewModel.load()

        XCTAssertEqual(viewModel.rows.map(\.id), ["hci-chi", "ai-aaai", "ai-aamas", "ai-neurips"])
    }

    func testCategoryRankTrackingOrderAndRepositoryOrderDoNotAffectSorting() async {
        let viewModel = makeViewModel(trackedIDs: ["graphics-siggraph", "interdisciplinary-kdd", "ai-neurips", "hci-chi"])

        await viewModel.load()

        XCTAssertEqual(viewModel.rows.map(\.id), ["interdisciplinary-kdd", "hci-chi", "ai-neurips", "graphics-siggraph"])
    }

    func testAbbreviationFullNameYearCaseTrimmedAndEmptySearch() async {
        let viewModel = makeViewModel(trackedIDs: ["ai-neurips", "hci-chi", "graphics-siggraph"])
        await viewModel.load()

        viewModel.searchQuery = "  chi  "
        viewModel.refreshSearch()
        XCTAssertEqual(viewModel.visibleRows.map(\.id), ["hci-chi"])

        viewModel.searchQuery = "neural information"
        viewModel.refreshSearch()
        XCTAssertEqual(viewModel.visibleRows.map(\.id), ["ai-neurips"])

        viewModel.searchQuery = "2027"
        viewModel.refreshSearch()
        XCTAssertEqual(viewModel.visibleRows.count, 3)

        viewModel.searchQuery = "   "
        viewModel.refreshSearch()
        XCTAssertEqual(viewModel.visibleRows.map(\.id), viewModel.rows.map(\.id))
    }

    func testSearchPreservesSortedOrderAndDoesNotMutateRows() async {
        let viewModel = makeViewModel(trackedIDs: ["ai-neurips", "hci-chi", "graphics-siggraph"])
        await viewModel.load()
        let originalRows = viewModel.rows

        viewModel.searchQuery = "conference"
        viewModel.refreshSearch()

        XCTAssertEqual(viewModel.rows, originalRows)
        XCTAssertEqual(viewModel.visibleRows.map(\.id), viewModel.rows.map(\.id))
    }

    func testOriginalTimezoneAoEAndIANAMetadataArePreserved() async {
        let viewModel = makeViewModel(trackedIDs: ["ai-neurips", "hci-chi"])

        await viewModel.load()

        XCTAssertTrue(viewModel.rows.first { $0.id == "ai-neurips" }?.deadline.originalDeadlineText.contains("AoE") ?? false)
        XCTAssertTrue(viewModel.rows.first { $0.id == "hci-chi" }?.deadline.originalDeadlineText.contains("America/Los_Angeles") ?? false)
    }

    func testBeijingTimeFormattingIsDeterministic() async {
        let viewModel = makeViewModel(trackedIDs: ["hci-chi"])

        await viewModel.load()

        XCTAssertEqual(viewModel.rows.first?.deadline.beijingTimeText, "Jun 26, 08:00 Beijing")
    }

    func testRemainingTextForDaysHoursMinutesTBDAndClosed() async {
        let viewModel = makeViewModel(trackedIDs: [
            "hci-chi",
            "interdisciplinary-sigir",
            "interdisciplinary-kdd",
            "graphics-siggraph",
            "graphics-acm-mm"
        ])

        await viewModel.load()

        XCTAssertEqual(viewModel.rows.first { $0.id == "hci-chi" }?.deadline.remainingText, "3 days")
        XCTAssertEqual(viewModel.rows.first { $0.id == "interdisciplinary-sigir" }?.deadline.remainingText, "18 hours")
        XCTAssertEqual(viewModel.rows.first { $0.id == "interdisciplinary-kdd" }?.deadline.remainingText, "45 min")
        XCTAssertEqual(viewModel.rows.first { $0.id == "graphics-siggraph" }?.deadline.remainingText, "TBD")
        XCTAssertEqual(viewModel.rows.first { $0.id == "graphics-acm-mm" }?.deadline.remainingText, "Closed")
    }

    func testRepositoryLoadErrorAndRetryRecovery() async {
        let conferenceRepository = ToggleFailingConferenceRepository(conferences: SeedConferenceCatalog.conferences())
        let viewModel = makeViewModel(conferenceRepository: conferenceRepository, trackedIDs: ["hci-chi"])

        conferenceRepository.shouldFail = true
        await viewModel.load()
        XCTAssertEqual(viewModel.presentationError?.id, "loadTracked")

        conferenceRepository.shouldFail = false
        await viewModel.retry()
        XCTAssertEqual(viewModel.loadState, .loaded)
        XCTAssertEqual(viewModel.rows.map(\.id), ["hci-chi"])
    }

    func testMissingWebsiteURLIsRepresented() async {
        let viewModel = makeViewModel(trackedIDs: ["hci-cscw"])

        await viewModel.load()

        XCTAssertNil(viewModel.rows.first?.websiteURL)
    }

    func testStableIdentityAfterRenameCategoryAndRankChange() async {
        let renamed = Conference(
            id: "ai-neurips",
            abbreviation: "NIPS",
            fullName: "Renamed Neural Information Processing Conference",
            category: SeedConferenceCatalog.interdisciplinary,
            ccfRank: .b,
            websiteURL: nil,
            editions: DomainTestFactory.conference(id: "ai-neurips").editions,
            lastUpdatedAt: nil
        )
        let viewModel = makeViewModel(conferences: [renamed], trackedIDs: ["ai-neurips"])

        await viewModel.load()

        XCTAssertEqual(viewModel.rows.first?.id, "ai-neurips")
        XCTAssertEqual(viewModel.rows.first?.abbreviation, "NIPS")
    }

    private func makeViewModel(
        conferences: [Conference] = SeedConferenceCatalog.conferences(),
        trackedIDs: [String],
        lastKnown: [Conference] = []
    ) -> TrackedConferenceListViewModel {
        makeViewModel(
            conferenceRepository: InMemoryConferenceRepository(conferences: conferences, updatedAt: SeedConferenceCatalog.seededAt),
            trackedIDs: trackedIDs,
            lastKnown: lastKnown
        )
    }

    private func makeViewModel(
        conferenceRepository: any ConferenceRepository,
        trackedIDs: [String],
        lastKnown: [Conference] = []
    ) -> TrackedConferenceListViewModel {
        let clock = FixedClock.standard
        let selection = DeadlineSelectionService(clock: clock)
        return TrackedConferenceListViewModel(
            conferenceRepository: conferenceRepository,
            trackedRepository: InMemoryTrackedConferenceRepository(
                trackedConferences: trackedIDs.map { TrackedConference(conferenceID: $0, addedAt: clock.now) }
            ),
            resolver: TrackedConferenceResolver(deadlineSelectionService: selection),
            sortingService: ConferenceSortingService(),
            deadlineCalculator: DeadlineCalculator(clock: clock),
            lastKnownConferences: lastKnown
        )
    }

    private func customConference(
        id: String,
        abbreviation: String,
        deadlines: [Deadline]
    ) -> Conference {
        Conference(
            id: id,
            abbreviation: abbreviation,
            fullName: "\(abbreviation) Conference",
            category: SeedConferenceCatalog.ai,
            ccfRank: .a,
            websiteURL: nil,
            editions: [
                ConferenceEdition(
                    id: "\(id)-2026",
                    conferenceID: id,
                    year: 2026,
                    conferenceStartDate: nil,
                    conferenceEndDate: nil,
                    location: nil,
                    deadlines: deadlines
                )
            ],
            lastUpdatedAt: nil
        )
    }

    private func customDeadline(id: String, days: Int) -> Deadline {
        Deadline(
            id: id,
            editionID: "ai-shuffled-2026",
            type: .paper,
            date: DomainTestFactory.date(daysFromReference: days),
            originalTimeZoneIdentifier: "UTC",
            rawDateValue: nil,
            comment: nil
        )
    }
}

private final class ToggleFailingConferenceRepository: ConferenceRepository {
    var shouldFail = false
    private let conferences: [Conference]

    init(conferences: [Conference]) {
        self.conferences = conferences
    }

    func loadAll() async throws -> [Conference] {
        if shouldFail {
            throw TestError.failure
        }
        return conferences
    }

    func conference(id: String) async throws -> Conference? {
        conferences.first { $0.id == id }
    }

    func replaceAll(_ conferences: [Conference], updatedAt: Date) async throws {}

    func lastUpdatedAt() async throws -> Date? {
        SeedConferenceCatalog.seededAt
    }
}

private enum TestError: Error {
    case failure
}
