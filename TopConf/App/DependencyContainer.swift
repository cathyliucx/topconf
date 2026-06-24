import Foundation
import SwiftData

struct DependencyContainer {
    let conferenceRepository: any ConferenceRepository
    let trackedRepository: any TrackedConferenceRepository
    let clock: any Clock
    let configuration: AppLaunchConfiguration

    static func make(
        configuration: AppLaunchConfiguration = .current(),
        inMemory: Bool? = nil
    ) throws -> DependencyContainer {
        let useInMemory = inMemory ?? configuration.isUITesting
        let container = try SwiftDataContainerFactory.makeContainer(isStoredInMemoryOnly: useInMemory)
        let clock: any Clock = configuration.isUITesting
            ? FixedDateClock(now: SeedConferenceCatalog.seededAt)
            : SystemClock()
        return DependencyContainer(
            conferenceRepository: SwiftDataConferenceRepository(container: container),
            trackedRepository: SwiftDataTrackedConferenceRepository(container: container),
            clock: clock,
            configuration: configuration
        )
    }

    @MainActor
    func makeConferenceManagementViewModel() -> ConferenceManagementViewModel {
        ConferenceManagementViewModel(
            conferenceRepository: conferenceRepository,
            trackedRepository: trackedRepository,
            trackingService: ConferenceTrackingService(clock: clock),
            discoveryService: ConferenceDiscoveryService(),
            supportedCategoryIDs: SeedConferenceCatalog.supportedCategoryIDs
        )
    }

    @MainActor
    func makeTrackedConferenceListViewModel() -> TrackedConferenceListViewModel {
        let deadlineSelectionService = DeadlineSelectionService(clock: clock)
        return TrackedConferenceListViewModel(
            conferenceRepository: conferenceRepository,
            trackedRepository: trackedRepository,
            resolver: TrackedConferenceResolver(deadlineSelectionService: deadlineSelectionService),
            sortingService: ConferenceSortingService(),
            deadlineCalculator: DeadlineCalculator(clock: clock)
        )
    }

    func seedIfNeeded() async throws {
        let existing = try await conferenceRepository.loadAll()
        if existing.isEmpty {
            try await conferenceRepository.replaceAll(
                SeedConferenceCatalog.conferences(),
                updatedAt: SeedConferenceCatalog.seededAt
            )
        }

        switch configuration.seedScenario {
        case .none, .empty, .zeroTracked:
            return
        case .oneUpcoming:
            try await seedTracked(conferenceIDs: ["hci-chi"])
        case .multipleSorted:
            try await seedTracked(conferenceIDs: [
                "ai-neurips",
                "graphics-siggraph",
                "ai-aamas",
                "graphics-acm-mm",
                "hci-chi",
                "interdisciplinary-kdd",
                "interdisciplinary-sigir",
                "ai-aaai"
            ])
        case .tbdAndClosed:
            try await seedTracked(conferenceIDs: ["graphics-siggraph", "graphics-acm-mm"])
        case .sourceUnavailable:
            try await seedTracked(conferenceIDs: ["missing-source-conf", "hci-chi"])
        case .nineTracked:
            try await seedTracked(conferenceIDs: [
                "ai-iclr",
                "ai-ijcai",
                "ai-mlsys",
                "ai-neurips",
                "graphics-acm-mm",
                "graphics-eurographics",
                "graphics-siggraph",
                "hci-chi",
                "hci-cscw",
            ])
        case .tenTracked:
            try await seedTracked(count: TrackingPolicy.maximumConferenceCount)
        }
    }

    private func seedTracked(count: Int) async throws {
        let conferences = try await conferenceRepository.loadAll()
        let existing = try await trackedRepository.loadAll()
        guard existing.isEmpty else {
            return
        }
        for conference in conferences.prefix(count) {
            try await trackedRepository.add(
                TrackedConference(conferenceID: conference.id, addedAt: SeedConferenceCatalog.seededAt)
            )
        }
    }

    private func seedTracked(conferenceIDs: [String]) async throws {
        let existing = try await trackedRepository.loadAll()
        guard existing.isEmpty else {
            return
        }
        for conferenceID in conferenceIDs {
            try await trackedRepository.add(
                TrackedConference(conferenceID: conferenceID, addedAt: SeedConferenceCatalog.seededAt)
            )
        }
    }
}
