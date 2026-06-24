import XCTest
@testable import TopConf

final class AppCompositionTests: XCTestCase {
    func testLaunchConfigurationParsesInitialSearchQuery() {
        let configuration = AppLaunchConfiguration.current(
            arguments: ["TopConf", "-UITesting", "-SeedScenario", "multipleSorted", "-InitialSearchQuery", "SIGIR"],
            environment: [:]
        )

        XCTAssertTrue(configuration.isUITesting)
        XCTAssertEqual(configuration.seedScenario, .multipleSorted)
        XCTAssertEqual(configuration.initialSearchQuery, "SIGIR")
    }

    func testProductionCompositionCanBeCreatedWithInMemorySwiftDataContainer() async throws {
        let container = try DependencyContainer.make(
            configuration: AppLaunchConfiguration(isUITesting: true, seedScenario: .empty, initialSearchQuery: nil),
            inMemory: true
        )

        try await container.seedIfNeeded()
        let conferences = try await container.conferenceRepository.loadAll()

        XCTAssertGreaterThanOrEqual(conferences.count, 11)
    }

    func testSeedDataIsInsertedOnlyWhenCatalogIsEmpty() async throws {
        let container = try DependencyContainer.make(
            configuration: AppLaunchConfiguration(isUITesting: true, seedScenario: .empty, initialSearchQuery: nil),
            inMemory: true
        )
        let custom = Conference(
            id: "custom-one",
            abbreviation: "CUSTOM",
            fullName: "Custom Conference",
            category: SeedConferenceCatalog.ai,
            ccfRank: .a,
            websiteURL: nil,
            editions: [],
            lastUpdatedAt: nil
        )

        try await container.conferenceRepository.replaceAll([custom], updatedAt: SeedConferenceCatalog.seededAt)
        try await container.seedIfNeeded()
        let conferences = try await container.conferenceRepository.loadAll()

        XCTAssertEqual(conferences.map(\.id), ["custom-one"])
    }

    func testTrackedRecordsSurviveCompositionRecreationWithSharedRepositories() async throws {
        let container = try DependencyContainer.make(
            configuration: AppLaunchConfiguration(isUITesting: true, seedScenario: .tenTracked, initialSearchQuery: nil),
            inMemory: true
        )

        try await container.seedIfNeeded()
        let tracked = try await container.trackedRepository.loadAll()

        XCTAssertEqual(tracked.count, TrackingPolicy.maximumConferenceCount)
    }

    @MainActor
    func testTrackedConferenceListViewModelCanBeComposed() throws {
        let container = try DependencyContainer.make(
            configuration: AppLaunchConfiguration(isUITesting: true, seedScenario: .oneUpcoming, initialSearchQuery: nil),
            inMemory: true
        )

        let viewModel = container.makeTrackedConferenceListViewModel()

        XCTAssertEqual(viewModel.loadState, .idle)
    }

    func testDeterministicTrackedListLaunchScenarios() async throws {
        let oneUpcoming = try DependencyContainer.make(
            configuration: AppLaunchConfiguration(isUITesting: true, seedScenario: .oneUpcoming, initialSearchQuery: nil),
            inMemory: true
        )
        try await oneUpcoming.seedIfNeeded()
        let oneUpcomingTracked = try await oneUpcoming.trackedRepository.loadAll().map(\.conferenceID)
        XCTAssertEqual(oneUpcomingTracked, ["hci-chi"])

        let zeroTracked = try DependencyContainer.make(
            configuration: AppLaunchConfiguration(isUITesting: true, seedScenario: .zeroTracked, initialSearchQuery: nil),
            inMemory: true
        )
        try await zeroTracked.seedIfNeeded()
        let zeroTrackedCount = try await zeroTracked.trackedRepository.count()
        XCTAssertEqual(zeroTrackedCount, 0)
    }

    func testCompleteCatalogMayExceedTrackedListLimit() async throws {
        let container = try DependencyContainer.make(
            configuration: AppLaunchConfiguration(isUITesting: true, seedScenario: .tenTracked, initialSearchQuery: nil),
            inMemory: true
        )

        try await container.seedIfNeeded()
        let catalog = try await container.conferenceRepository.loadAll()
        let tracked = try await container.trackedRepository.loadAll()

        XCTAssertGreaterThan(catalog.count, TrackingPolicy.maximumConferenceCount)
        XCTAssertEqual(tracked.count, TrackingPolicy.maximumConferenceCount)
    }
}
