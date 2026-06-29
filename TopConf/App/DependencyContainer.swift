import Foundation
import SwiftData

struct DependencyContainer {
    let conferenceRepository: any ConferenceRepository
    let trackedRepository: any TrackedConferenceRepository
    let reminderRepository: any ReminderRepository
    let reminderManager: any DeadlineReminderManaging
    let catalogSynchronizer: (any ConferenceCatalogSynchronizing)?
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
        let reminderRepository = SwiftDataReminderRepository(container: container)
        let conferenceRepository = SwiftDataConferenceRepository(container: container)
        let synchronizer: (any ConferenceCatalogSynchronizing)? = configuration.isUITesting
            ? nil
            : ConferenceCatalogSynchronizer(
                remoteSource: GitHubConferenceSource(clock: clock),
                conferenceRepository: conferenceRepository,
                clock: clock
            )
        return DependencyContainer(
            conferenceRepository: conferenceRepository,
            trackedRepository: SwiftDataTrackedConferenceRepository(container: container),
            reminderRepository: reminderRepository,
            reminderManager: DeadlineNotificationService(
                reminderRepository: reminderRepository,
                scheduler: configuration.isUITesting ? SilentNotificationScheduler() : UserNotificationScheduler(),
                clock: clock
            ),
            catalogSynchronizer: synchronizer,
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
            deadlineCalculator: DeadlineCalculator(clock: clock),
            reminderManager: reminderManager
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
            try await seedTracked(conferenceIDs: ["ai-iclr"])
        case .multipleSorted:
            try await seedTracked(conferenceIDs: [
                "ai-neurips",
                "graphics-siggraph",
                "ai-aamas",
                "graphics-eurographics",
                "hci-uist",
                "interdisciplinary-www",
                "interdisciplinary-sigir",
                "ai-aaai",
                "ai-iclr"
            ])
        case .tbdAndClosed:
            try await seedTracked(conferenceIDs: ["graphics-siggraph"])
        case .sourceUnavailable:
            try await seedTracked(conferenceIDs: ["missing-source-conf", "hci-uist"])
        case .nineTracked:
            try await seedTracked(conferenceIDs: [
                "ai-iclr",
                "ai-ijcai",
                "ai-mlsys",
                "ai-neurips",
                "graphics-eurographics",
                "graphics-siggraph",
                "hci-cscw",
                "hci-uist",
                "interdisciplinary-cikm",
            ])
        case .tenTracked:
            try await seedTracked(count: TrackingPolicy.maximumConferenceCount)
        }
    }

    func refreshCatalogInBackground() async -> Bool {
        guard let catalogSynchronizer else {
            return false
        }
        let didRefresh = await catalogSynchronizer.refreshCatalog()
        if didRefresh {
            await removeTrackedConferencesMissingFromCurrentCatalog()
            await synchronizeRemindersForCurrentCatalog()
        }
        return didRefresh
    }

    func reconcileTrackedConferencesWithAcceptedCatalogIfPresent() async {
        do {
            guard let lastUpdatedAt = try await conferenceRepository.lastUpdatedAt(),
                  lastUpdatedAt != SeedConferenceCatalog.seededAt else {
                return
            }
            await removeTrackedConferencesMissingFromCurrentCatalog()
            await synchronizeRemindersForCurrentCatalog()
        } catch {
            return
        }
    }

    private func removeTrackedConferencesMissingFromCurrentCatalog() async {
        do {
            let catalogIDs = Set(try await conferenceRepository.loadAll().map(\.id))
            guard !catalogIDs.isEmpty else {
                return
            }

            let tracked = try await trackedRepository.loadAll()
            let orphanedConferenceIDs = tracked
                .map(\.conferenceID)
                .filter { !catalogIDs.contains($0) }

            for conferenceID in orphanedConferenceIDs {
                try await trackedRepository.remove(conferenceID: conferenceID)
            }
        } catch {
            return
        }
    }

    func synchronizeRemindersForCurrentCatalog() async {
        do {
            let tracked = try await trackedRepository.loadAll()
            let catalog = try await conferenceRepository.loadAll()
            let deadlineSelectionService = DeadlineSelectionService(clock: clock)
            let resolver = TrackedConferenceResolver(deadlineSelectionService: deadlineSelectionService)
            let calculator = DeadlineCalculator(clock: clock)
            let rowContexts = tracked.compactMap { trackedConference in
                let resolved = resolver.resolve(
                    trackedConference: trackedConference,
                    currentConferences: catalog,
                    lastKnownConferences: []
                )
                return Self.reminderContext(for: resolved, calculator: calculator)
            }
            let existingRules = try await reminderRepository.loadAll()
            let existingContexts = Self.reminderContextsForExistingRules(
                existingRules,
                catalog: catalog,
                calculator: calculator,
                clock: clock
            )
            let contexts = Self.deduplicatedReminderContexts(rowContexts + existingContexts)
            await reminderManager.synchronizeReminders(for: contexts)
        } catch {
            return
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

    private static func reminderContext(
        for resolved: ResolvedTrackedConference,
        calculator: DeadlineCalculator
    ) -> DeadlineReminderContext? {
        guard let deadline = resolved.primaryDeadline else {
            return nil
        }
        let presentation = DeadlinePresentation.make(
            deadline: deadline,
            availability: resolved.availability,
            calculator: calculator
        )
        let title = resolved.conference.map { "\($0.abbreviation) \($0.fullName)" } ?? resolved.conferenceID
        return DeadlineReminderContext(
            deadlineID: deadline.id,
            conferenceTitle: title,
            deadlineTypeText: presentation.typeText,
            deadlineDate: deadline.date,
            availability: resolved.availability
        )
    }

    private static func reminderContextsForExistingRules(
        _ rules: [ReminderRule],
        catalog: [Conference],
        calculator: DeadlineCalculator,
        clock: any Clock
    ) -> [DeadlineReminderContext] {
        rules.compactMap { rule in
            for conference in catalog {
                for edition in conference.editions {
                    if let deadline = edition.deadlines.first(where: { $0.id == rule.deadlineID }) {
                        return reminderContext(
                            conference: conference,
                            deadline: deadline,
                            availability: availability(for: deadline, clock: clock),
                            calculator: calculator
                        )
                    }
                }
            }
            return nil
        }
    }

    private static func reminderContext(
        conference: Conference,
        deadline: Deadline,
        availability: ConferenceAvailability,
        calculator: DeadlineCalculator
    ) -> DeadlineReminderContext {
        let presentation = DeadlinePresentation.make(
            deadline: deadline,
            availability: availability,
            calculator: calculator
        )
        return DeadlineReminderContext(
            deadlineID: deadline.id,
            conferenceTitle: "\(conference.abbreviation) \(conference.fullName)",
            deadlineTypeText: presentation.typeText,
            deadlineDate: deadline.date,
            availability: availability
        )
    }

    private static func availability(for deadline: Deadline, clock: any Clock) -> ConferenceAvailability {
        guard let date = deadline.date else {
            return .deadlineToBeDetermined
        }
        return date > clock.now ? .available : .allDeadlinesClosed
    }

    private static func deduplicatedReminderContexts(
        _ contexts: [DeadlineReminderContext]
    ) -> [DeadlineReminderContext] {
        var keyedContexts: [String: DeadlineReminderContext] = [:]
        for context in contexts {
            keyedContexts[context.deadlineID] = context
        }
        return keyedContexts.values.sorted { $0.deadlineID < $1.deadlineID }
    }
}
