import XCTest
@testable import TopConf

@MainActor
final class ConferenceManagementViewModelTests: XCTestCase {
    func testInitialStateBeforeLoad() {
        let viewModel = makeViewModel()

        XCTAssertEqual(viewModel.loadState, .idle)
        XCTAssertEqual(viewModel.trackingCount, 0)
        XCTAssertEqual(viewModel.trackingCountText, "0 / 10")
        XCTAssertEqual(viewModel.selectedCategoryIDs, SeedConferenceCatalog.supportedCategoryIDs)
        XCTAssertEqual(viewModel.selectedRanks, [.a])
    }

    func testSuccessfulLoadDefaultFiltersAndDeterministicOrdering() async {
        let viewModel = makeViewModel()

        await viewModel.load()

        XCTAssertEqual(viewModel.loadState, .loaded)
        XCTAssertEqual(viewModel.categoryOptions.map(\.id).sorted(), SeedConferenceCatalog.supportedCategoryIDs.sorted())
        XCTAssertGreaterThan(viewModel.allConferences.count, TrackingPolicy.maximumConferenceCount)
        XCTAssertGreaterThan(viewModel.discoveredConferences.count, TrackingPolicy.maximumConferenceCount)
        XCTAssertEqual(viewModel.availableConferences.map(\.abbreviation), viewModel.availableConferences.map(\.abbreviation).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending })
        XCTAssertTrue(viewModel.availableConferences.allSatisfy { $0.rank == .a })
    }

    func testEmptyCatalogLoadsEmptyState() async {
        let viewModel = makeViewModel(conferences: [])

        await viewModel.load()

        XCTAssertEqual(viewModel.availableConferences, [])
        XCTAssertEqual(viewModel.allConferences, [])
        XCTAssertEqual(viewModel.discoveredConferences, [])
        XCTAssertEqual(viewModel.trackedConferences, [])
        XCTAssertEqual(viewModel.trackingCountText, "0 / 10")
    }

    func testCategoryRankAndSearchFiltering() async {
        let viewModel = makeViewModel()

        await viewModel.load()
        viewModel.toggleCategory(SeedConferenceCatalog.ai.sourceID)
        viewModel.toggleCategory(SeedConferenceCatalog.graphics.sourceID)
        viewModel.toggleCategory(SeedConferenceCatalog.interdisciplinary.sourceID)
        viewModel.toggleRank(.b)
        viewModel.searchQuery = "  uist  "
        viewModel.refreshFilters()

        XCTAssertEqual(viewModel.availableConferences.map(\.id), ["hci-uist"])
    }

    func testMultipleCategoryAndRankUnionWithIntersection() async {
        let viewModel = makeViewModel()

        await viewModel.load()
        viewModel.selectedCategoryIDs = [SeedConferenceCatalog.graphics.sourceID, SeedConferenceCatalog.interdisciplinary.sourceID]
        viewModel.selectedRanks = [.a, .b]
        viewModel.refreshFilters()

        XCTAssertTrue(viewModel.availableConferences.contains { $0.id == "graphics-acm-mm" })
        XCTAssertTrue(viewModel.availableConferences.contains { $0.id == "interdisciplinary-recsys" })
        XCTAssertFalse(viewModel.availableConferences.contains { $0.categorySourceID == SeedConferenceCatalog.ai.sourceID })
    }

    func testSearchMatchesFullNameYearCaseAndEmptyQuery() async {
        let viewModel = makeViewModel()

        await viewModel.load()
        viewModel.searchQuery = "learning representations"
        viewModel.refreshFilters()
        XCTAssertEqual(viewModel.availableConferences.map(\.id), ["ai-iclr"])

        viewModel.searchQuery = "2027"
        viewModel.refreshFilters()
        XCTAssertFalse(viewModel.availableConferences.isEmpty)

        viewModel.searchQuery = "   "
        viewModel.refreshFilters()
        XCTAssertGreaterThan(viewModel.availableConferences.count, 1)
    }

    func testCatalogDiscoveryAndSearchAreNotCappedAtTrackingLimit() async {
        let viewModel = makeViewModel()

        await viewModel.load()
        XCTAssertGreaterThan(viewModel.allConferences.count, TrackingPolicy.maximumConferenceCount)

        viewModel.selectedRanks = []
        viewModel.searchQuery = "conference"
        viewModel.refreshFilters()

        XCTAssertGreaterThan(viewModel.discoveredConferences.count, TrackingPolicy.maximumConferenceCount)
        XCTAssertEqual(viewModel.trackingCount, 0)
        XCTAssertTrue(viewModel.discoveredConferences.contains { $0.id == "interdisciplinary-wsdm" })
    }

    func testCategoryAndRankResultsCanExceedTrackingLimit() async {
        let viewModel = makeViewModel()

        await viewModel.load()
        viewModel.selectedRanks = [.b]
        viewModel.refreshFilters()

        XCTAssertGreaterThan(viewModel.discoveredConferences.count, TrackingPolicy.maximumConferenceCount)
        XCTAssertTrue(viewModel.discoveredConferences.allSatisfy { $0.rank == .b })
        XCTAssertTrue(viewModel.discoveredConferences.contains { $0.id == "interdisciplinary-wsdm" })
    }

    func testFullTrackedSetDoesNotHideCatalogOrDiscoveryResults() async {
        let tracked = SeedConferenceCatalog.conferences()
            .sorted { $0.id < $1.id }
            .prefix(TrackingPolicy.maximumConferenceCount)
            .map { TrackedConference(conferenceID: $0.id, addedAt: SeedConferenceCatalog.seededAt) }
        let viewModel = makeViewModel(tracked: tracked)

        await viewModel.load()
        viewModel.selectedRanks = []
        viewModel.searchQuery = "conference"
        viewModel.refreshFilters()

        XCTAssertEqual(viewModel.trackingCount, TrackingPolicy.maximumConferenceCount)
        XCTAssertGreaterThan(viewModel.allConferences.count, TrackingPolicy.maximumConferenceCount)
        XCTAssertGreaterThan(viewModel.discoveredConferences.count, TrackingPolicy.maximumConferenceCount)
        XCTAssertFalse(viewModel.discoveredConferences.first { !$0.isTracked }?.canAdd ?? true)
        XCTAssertEqual(viewModel.trackedConferences.count, TrackingPolicy.maximumConferenceCount)
    }

    func testAddTenthRejectEleventhRemoveAndRestoreCapability() async {
        let tracked = [
            "ai-aaai",
            "ai-iclr",
            "ai-ijcai",
            "ai-mlsys",
            "ai-neurips",
            "graphics-acm-mm",
            "graphics-eurographics",
            "graphics-siggraph",
            "hci-chi",
        ].map {
            TrackedConference(conferenceID: $0, addedAt: SeedConferenceCatalog.seededAt)
        }
        let viewModel = makeViewModel(tracked: tracked)

        await viewModel.load()
        XCTAssertEqual(viewModel.trackingCountText, "9 / 10")

        await viewModel.addConference(id: "hci-uist")
        XCTAssertEqual(viewModel.trackingCountText, "10 / 10")
        XCTAssertFalse(viewModel.canAddAnotherConference)

        await viewModel.addConference(id: "interdisciplinary-www")
        XCTAssertEqual(viewModel.presentationError?.id, "limitReached")
        XCTAssertEqual(viewModel.trackingCountText, "10 / 10")

        await viewModel.removeConference(id: "hci-uist")
        XCTAssertEqual(viewModel.trackingCountText, "9 / 10")
        XCTAssertTrue(viewModel.canAddAnotherConference)
    }

    func testOrphanTrackedRowsDoNotAppearOrConsumeTrackingSlots() async {
        let tracked = [
            "ai-aaai",
            "ai-iclr",
            "ai-ijcai",
            "ai-mlsys",
            "ai-neurips",
            "graphics-eurographics",
            "graphics-siggraph",
            "hci-uist",
            "interdisciplinary-cikm",
            "graphics-acm-mm",
            "hci-chi"
        ].map {
            TrackedConference(conferenceID: $0, addedAt: SeedConferenceCatalog.seededAt)
        }
        let conferences = SeedConferenceCatalog.conferences().filter {
            $0.id != "graphics-acm-mm" && $0.id != "hci-chi"
        }
        let viewModel = makeViewModel(conferences: conferences, tracked: tracked)

        await viewModel.load()

        XCTAssertEqual(viewModel.trackingCountText, "9 / 10")
        XCTAssertEqual(viewModel.trackedConferences.count, 9)
        XCTAssertFalse(viewModel.trackedConferences.contains { $0.id == "graphics-acm-mm" })
        XCTAssertFalse(viewModel.trackedConferences.contains { $0.id == "hci-chi" })
        XCTAssertTrue(viewModel.canAddAnotherConference)
    }

    func testOrphanTrackedRowsDoNotBlockAddingTenthConference() async {
        let tracked = [
            "ai-aaai",
            "ai-iclr",
            "ai-ijcai",
            "ai-mlsys",
            "ai-neurips",
            "graphics-eurographics",
            "graphics-siggraph",
            "hci-uist",
            "interdisciplinary-cikm",
            "graphics-acm-mm",
            "hci-chi"
        ].map {
            TrackedConference(conferenceID: $0, addedAt: SeedConferenceCatalog.seededAt)
        }
        let conferences = SeedConferenceCatalog.conferences().filter {
            $0.id != "graphics-acm-mm" && $0.id != "hci-chi"
        }
        let viewModel = makeViewModel(conferences: conferences, tracked: tracked)

        await viewModel.load()
        await viewModel.addConference(id: "interdisciplinary-www")

        XCTAssertEqual(viewModel.trackingCountText, "10 / 10")
        XCTAssertTrue(viewModel.trackedConferences.contains { $0.id == "interdisciplinary-www" })
        XCTAssertFalse(viewModel.canAddAnotherConference)
    }

    func testDuplicateMissingAndRemoveMissingAreDeterministic() async {
        let viewModel = makeViewModel(tracked: [
            TrackedConference(conferenceID: "ai-neurips", addedAt: SeedConferenceCatalog.seededAt)
        ])

        await viewModel.load()
        await viewModel.addConference(id: "ai-neurips")
        XCTAssertEqual(viewModel.presentationError?.id, "alreadyTracked")

        viewModel.clearError()
        await viewModel.addConference(id: "missing")
        XCTAssertEqual(viewModel.presentationError?.id, "conferenceNotFound")

        viewModel.clearError()
        await viewModel.removeConference(id: "missing")
        XCTAssertEqual(viewModel.presentationError?.id, "notTracked")
    }

    func testTrackedStateAndTrackedListIgnoreDiscoveryFilters() async {
        let viewModel = makeViewModel(tracked: [
            TrackedConference(conferenceID: "ai-neurips", addedAt: SeedConferenceCatalog.seededAt)
        ])

        await viewModel.load()
        viewModel.selectedCategoryIDs = [SeedConferenceCatalog.graphics.sourceID]
        viewModel.refreshFilters()

        XCTAssertFalse(viewModel.availableConferences.contains { $0.id == "ai-neurips" })
        XCTAssertEqual(viewModel.trackedConferences.map(\.id), ["ai-neurips"])
    }

    func testStableTrackingIdentityAfterRenameRankAndCategoryChange() async {
        let renamed = Conference(
            id: "ai-neurips",
            abbreviation: "NIPS",
            fullName: "Renamed Neural Information Processing Conference",
            category: SeedConferenceCatalog.interdisciplinary,
            ccfRank: .b,
            websiteURL: nil,
            editions: [],
            lastUpdatedAt: nil
        )
        let viewModel = makeViewModel(
            conferences: [renamed],
            tracked: [TrackedConference(conferenceID: "ai-neurips", addedAt: SeedConferenceCatalog.seededAt)]
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.trackedConferences.first?.id, "ai-neurips")
        XCTAssertEqual(viewModel.trackedConferences.first?.abbreviation, "NIPS")
        XCTAssertEqual(viewModel.trackedConferences.first?.rank, .b)
    }

    func testRepositoryErrorsSurfaceRecoverableState() async {
        let viewModel = ConferenceManagementViewModel(
            conferenceRepository: FailingConferenceRepository(),
            trackedRepository: InMemoryTrackedConferenceRepository(),
            trackingService: ConferenceTrackingService(clock: FixedClock.standard)
        )

        await viewModel.load()

        if case .failed = viewModel.loadState {
            XCTAssertEqual(viewModel.presentationError?.id, "load")
        } else {
            XCTFail("Expected failed load state")
        }
    }

    func testAddAndRemoveRepositoryErrorsLeaveStateConsistent() async {
        let trackedRepository = FailingTrackedConferenceRepository()
        let viewModel = ConferenceManagementViewModel(
            conferenceRepository: InMemoryConferenceRepository(conferences: SeedConferenceCatalog.conferences()),
            trackedRepository: trackedRepository,
            trackingService: ConferenceTrackingService(clock: FixedClock.standard)
        )

        await viewModel.load()
        await viewModel.addConference(id: "ai-neurips")
        XCTAssertEqual(viewModel.presentationError?.id, "add")
        XCTAssertEqual(viewModel.trackingCount, 0)
    }

    func testRepeatedLoadDoesNotDuplicateItems() async {
        let viewModel = makeViewModel()

        await viewModel.load()
        await viewModel.load()

        XCTAssertEqual(Set(viewModel.availableConferences.map(\.id)).count, viewModel.availableConferences.count)
    }

    private func makeViewModel(
        conferences: [Conference] = SeedConferenceCatalog.conferences(),
        tracked: [TrackedConference] = []
    ) -> ConferenceManagementViewModel {
        ConferenceManagementViewModel(
            conferenceRepository: InMemoryConferenceRepository(conferences: conferences, updatedAt: SeedConferenceCatalog.seededAt),
            trackedRepository: InMemoryTrackedConferenceRepository(trackedConferences: tracked),
            trackingService: ConferenceTrackingService(clock: FixedClock.standard)
        )
    }
}

private struct FailingConferenceRepository: ConferenceRepository {
    func loadAll() async throws -> [Conference] { throw TestError.failure }
    func conference(id: String) async throws -> Conference? { throw TestError.failure }
    func replaceAll(_ conferences: [Conference], updatedAt: Date) async throws { throw TestError.failure }
    func lastUpdatedAt() async throws -> Date? { throw TestError.failure }
}

private actor FailingTrackedConferenceRepository: TrackedConferenceRepository {
    func loadAll() async throws -> [TrackedConference] { [] }
    func contains(conferenceID: String) async throws -> Bool { false }
    func add(_ trackedConference: TrackedConference) async throws { throw TestError.failure }
    func remove(conferenceID: String) async throws { throw TestError.failure }
    func count() async throws -> Int { 0 }
}

private enum TestError: Error {
    case failure
}
