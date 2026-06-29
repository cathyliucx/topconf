import Foundation
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

    func testUITestSeedScenariosDeclareOnboardingStateExplicitly() {
        XCTAssertFalse(SeedScenario.empty.onboardingCompleted)
        XCTAssertFalse(SeedScenario.none.onboardingCompleted)
        XCTAssertTrue(SeedScenario.zeroTracked.onboardingCompleted)
        XCTAssertTrue(SeedScenario.oneUpcoming.onboardingCompleted)
        XCTAssertTrue(SeedScenario.multipleSorted.onboardingCompleted)
        XCTAssertTrue(SeedScenario.nineTracked.onboardingCompleted)
        XCTAssertTrue(SeedScenario.tenTracked.onboardingCompleted)
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

    func testProductionCompositionUsesSystemClockAndDoesNotSeedTrackedConferencesByDefault() async throws {
        let container = try DependencyContainer.make(
            configuration: AppLaunchConfiguration(isUITesting: false, seedScenario: .none, initialSearchQuery: nil),
            inMemory: true
        )

        try await container.seedIfNeeded()
        let conferences = try await container.conferenceRepository.loadAll()
        let trackedCount = try await container.trackedRepository.count()

        XCTAssertTrue(container.clock is SystemClock)
        XCTAssertGreaterThanOrEqual(conferences.count, 11)
        XCTAssertEqual(trackedCount, 0)
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
        XCTAssertEqual(oneUpcomingTracked, ["ai-iclr"])

        let zeroTracked = try DependencyContainer.make(
            configuration: AppLaunchConfiguration(isUITesting: true, seedScenario: .zeroTracked, initialSearchQuery: nil),
            inMemory: true
        )
        try await zeroTracked.seedIfNeeded()
        let zeroTrackedCount = try await zeroTracked.trackedRepository.count()
        XCTAssertEqual(zeroTrackedCount, 0)
    }

    func testBundledCatalogLoadingDoesNotCreateTrackedRecordsForFreshInstall() async throws {
        let container = try DependencyContainer.make(
            configuration: AppLaunchConfiguration(isUITesting: false, seedScenario: .none, initialSearchQuery: nil),
            inMemory: true
        )

        try await container.seedIfNeeded()
        let catalogCount = try await container.conferenceRepository.loadAll().count
        let tracked = try await container.trackedRepository.loadAll()

        XCTAssertGreaterThan(catalogCount, TrackingPolicy.maximumConferenceCount)
        XCTAssertTrue(tracked.isEmpty)
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

    func testFirstLaunchOfflineFallbackDoesNotCreateTrackedRecordsForNormalProductionLaunch() async throws {
        let conferenceRepository = InMemoryConferenceRepository()
        let trackedRepository = InMemoryTrackedConferenceRepository()
        let container = DependencyContainer(
            conferenceRepository: conferenceRepository,
            trackedRepository: trackedRepository,
            reminderRepository: InMemoryReminderRepository(),
            reminderManager: SpyReminderManager(),
            catalogSynchronizer: StaticCatalogSynchronizer(didRefresh: false),
            clock: SystemClock(),
            configuration: AppLaunchConfiguration(isUITesting: false, seedScenario: .none, initialSearchQuery: nil)
        )

        try await container.seedIfNeeded()
        let didRefresh = await container.refreshCatalogInBackground()
        let catalog = try await conferenceRepository.loadAll()
        let tracked = try await trackedRepository.loadAll()

        XCTAssertFalse(didRefresh)
        XCTAssertGreaterThan(catalog.count, TrackingPolicy.maximumConferenceCount)
        XCTAssertTrue(tracked.isEmpty)
    }

    func testFirstLaunchOfflineFallbackSeedsEmptyCatalogWhenRefreshFails() async throws {
        let conferenceRepository = InMemoryConferenceRepository()
        let trackedRepository = InMemoryTrackedConferenceRepository()
        let reminderRepository = InMemoryReminderRepository(rules: [
            ReminderFixtures.rule(deadlineID: "ai-iclr-2027-paper", offsetSeconds: 24 * 60 * 60)
        ])
        let reminderManager = SpyReminderManager()
        let container = DependencyContainer(
            conferenceRepository: conferenceRepository,
            trackedRepository: trackedRepository,
            reminderRepository: reminderRepository,
            reminderManager: reminderManager,
            catalogSynchronizer: StaticCatalogSynchronizer(didRefresh: false),
            clock: FixedClock.standard,
            configuration: AppLaunchConfiguration(isUITesting: false, seedScenario: .oneUpcoming, initialSearchQuery: nil)
        )

        try await container.seedIfNeeded()
        let didRefresh = await container.refreshCatalogInBackground()
        let catalog = try await conferenceRepository.loadAll()
        let tracked = try await trackedRepository.loadAll()
        let reminderRules = try await reminderRepository.loadAll()

        XCTAssertFalse(didRefresh)
        XCTAssertGreaterThanOrEqual(catalog.count, 11)
        XCTAssertTrue(catalog.contains { $0.id == "ai-iclr" })
        XCTAssertEqual(tracked.map(\.conferenceID), ["ai-iclr"])
        XCTAssertEqual(reminderRules.map(\.id), ["topconf.ai-iclr-2027-paper.86400"])
        let synchronizedContexts = await reminderManager.synchronizedContexts()
        XCTAssertEqual(synchronizedContexts, [])
    }

    func testPersistedCacheRemainsWhenRefreshFails() async throws {
        let existing = ConferenceFixtures.upcomingAIConference()
        let conferenceRepository = InMemoryConferenceRepository(
            conferences: [existing],
            updatedAt: DomainTestFactory.referenceDate
        )
        let container = DependencyContainer(
            conferenceRepository: conferenceRepository,
            trackedRepository: InMemoryTrackedConferenceRepository(),
            reminderRepository: InMemoryReminderRepository(),
            reminderManager: SpyReminderManager(),
            catalogSynchronizer: StaticCatalogSynchronizer(didRefresh: false),
            clock: FixedClock.standard,
            configuration: AppLaunchConfiguration(isUITesting: false, seedScenario: .empty, initialSearchQuery: nil)
        )

        try await container.seedIfNeeded()
        let didRefresh = await container.refreshCatalogInBackground()
        let catalog = try await conferenceRepository.loadAll()
        let lastUpdatedAt = try await conferenceRepository.lastUpdatedAt()

        XCTAssertFalse(didRefresh)
        XCTAssertEqual(catalog, [existing])
        XCTAssertEqual(lastUpdatedAt, DomainTestFactory.referenceDate)
    }

    func testRejectedRemoteRefreshPreservesCatalogAndDoesNotResynchronizeReminders() async throws {
        let existing = conference()
        let conferenceRepository = InMemoryConferenceRepository(
            conferences: [existing],
            updatedAt: DomainTestFactory.referenceDate
        )
        let reminderRepository = InMemoryReminderRepository(rules: [
            ReminderFixtures.rule(offsetSeconds: 24 * 60 * 60)
        ])
        let reminderManager = SpyReminderManager()
        let container = DependencyContainer(
            conferenceRepository: conferenceRepository,
            trackedRepository: InMemoryTrackedConferenceRepository(trackedConferences: [
                TrackedConference(conferenceID: "ai-neurips", addedAt: DomainTestFactory.referenceDate)
            ]),
            reminderRepository: reminderRepository,
            reminderManager: reminderManager,
            catalogSynchronizer: ConferenceCatalogSynchronizer(
                remoteSource: ThrowingAppCompositionRemoteSource(error: .incompleteBatch("too small")),
                conferenceRepository: conferenceRepository,
                clock: FixedClock.standard
            ),
            clock: FixedClock.standard,
            configuration: AppLaunchConfiguration(isUITesting: false, seedScenario: .empty, initialSearchQuery: nil)
        )

        let didRefresh = await container.refreshCatalogInBackground()
        let catalog = try await conferenceRepository.loadAll()
        let lastUpdatedAt = try await conferenceRepository.lastUpdatedAt()
        let rules = try await reminderRepository.loadAll()
        let synchronizedContexts = await reminderManager.synchronizedContexts()

        XCTAssertFalse(didRefresh)
        XCTAssertEqual(catalog, [existing])
        XCTAssertEqual(lastUpdatedAt, DomainTestFactory.referenceDate)
        XCTAssertEqual(rules.map(\.id), ["topconf.ai-neurips-2026-paper.86400"])
        XCTAssertEqual(synchronizedContexts, [])
    }

    func testRemoteDeadlineChangeResynchronizesRemindersFromAppLayer() async throws {
        let oldDeadline = DomainTestFactory.deadline(
            id: ReminderFixtures.neuripsPaperDeadlineID,
            editionID: "ai-neurips-2026",
            type: .paper,
            date: DomainTestFactory.date(daysFromReference: 30)
        )
        let newDeadline = DomainTestFactory.deadline(
            id: ReminderFixtures.neuripsPaperDeadlineID,
            editionID: "ai-neurips-2026",
            type: .paper,
            date: DomainTestFactory.date(daysFromReference: 60)
        )
        let oldConference = conference(deadline: oldDeadline)
        let newConference = conference(deadline: newDeadline)
        let reminderRepository = InMemoryReminderRepository()
        let scheduler = AppCompositionMockNotificationScheduler()
        let reminderManager = DeadlineNotificationService(
            reminderRepository: reminderRepository,
            scheduler: scheduler,
            clock: FixedClock.standard
        )
        _ = await reminderManager.saveReminderOffsets(
            [24 * 60 * 60],
            for: reminderContext(deadlineDate: oldDeadline.date)
        )
        let container = makeRefreshingContainer(
            initialCatalog: [oldConference],
            remoteCatalog: [newConference],
            reminderRepository: reminderRepository,
            reminderManager: reminderManager
        )

        let didRefresh = await container.refreshCatalogInBackground()
        let snapshot = await scheduler.snapshot()
        let rules = try await reminderRepository.loadAll()

        XCTAssertTrue(didRefresh)
        XCTAssertEqual(rules.map(\.id), ["topconf.ai-neurips-2026-paper.86400"])
        XCTAssertEqual(snapshot.scheduled.map(\.identifier), ["topconf.ai-neurips-2026-paper.86400"])
        XCTAssertEqual(snapshot.scheduled.map(\.deliveryDate), [DomainTestFactory.date(daysFromReference: 59)])
        XCTAssertEqual(snapshot.removedDeadlineIDs, [
            ReminderFixtures.neuripsPaperDeadlineID,
            ReminderFixtures.neuripsPaperDeadlineID
        ])
    }

    func testRemoteTBDDeadlineCancelsPendingNotificationsButPreservesRule() async throws {
        let tbdDeadline = DomainTestFactory.deadline(
            id: ReminderFixtures.neuripsPaperDeadlineID,
            editionID: "ai-neurips-2026",
            type: .paper,
            date: nil,
            rawDateValue: "TBD"
        )
        let reminderRepository = InMemoryReminderRepository(rules: [
            ReminderFixtures.rule(offsetSeconds: 24 * 60 * 60)
        ])
        let scheduler = AppCompositionMockNotificationScheduler(seed: [
            notificationRequest(deliveryDate: DomainTestFactory.date(daysFromReference: 29))
        ])
        let reminderManager = DeadlineNotificationService(
            reminderRepository: reminderRepository,
            scheduler: scheduler,
            clock: FixedClock.standard
        )
        let container = makeRefreshingContainer(
            initialCatalog: [conference()],
            remoteCatalog: [conference(deadline: tbdDeadline)],
            reminderRepository: reminderRepository,
            reminderManager: reminderManager
        )

        let didRefresh = await container.refreshCatalogInBackground()
        let snapshot = await scheduler.snapshot()
        let rules = try await reminderRepository.loadAll()

        XCTAssertTrue(didRefresh)
        XCTAssertEqual(rules.map(\.id), ["topconf.ai-neurips-2026-paper.86400"])
        XCTAssertTrue(snapshot.scheduled.isEmpty)
        XCTAssertEqual(snapshot.removedDeadlineIDs, [ReminderFixtures.neuripsPaperDeadlineID])
    }

    func testUnavailableConferenceRemovesObsoleteReminderRulesAndNotifications() async throws {
        let reminderRepository = InMemoryReminderRepository(rules: [
            ReminderFixtures.rule(offsetSeconds: 24 * 60 * 60)
        ])
        let scheduler = AppCompositionMockNotificationScheduler(seed: [
            notificationRequest(deliveryDate: DomainTestFactory.date(daysFromReference: 29))
        ])
        let reminderManager = DeadlineNotificationService(
            reminderRepository: reminderRepository,
            scheduler: scheduler,
            clock: FixedClock.standard
        )
        let container = makeRefreshingContainer(
            initialCatalog: [conference()],
            remoteCatalog: [ConferenceFixtures.multipleDeadlineConference()],
            reminderRepository: reminderRepository,
            reminderManager: reminderManager
        )

        let didRefresh = await container.refreshCatalogInBackground()
        let snapshot = await scheduler.snapshot()
        let rules = try await reminderRepository.loadAll()

        XCTAssertTrue(didRefresh)
        XCTAssertTrue(rules.isEmpty)
        XCTAssertTrue(snapshot.scheduled.isEmpty)
        XCTAssertEqual(snapshot.removedDeadlineIDs, [ReminderFixtures.neuripsPaperDeadlineID])
    }

    func testRemovedDeadlineRemovesObsoleteReminderRulesAndNotifications() async throws {
        let conferenceWithoutDeadlines = DomainTestFactory.conference(
            id: "ai-neurips",
            editions: [
                DomainTestFactory.edition(
                    conferenceID: "ai-neurips",
                    year: 2026,
                    deadlines: []
                )
            ]
        )
        let reminderRepository = InMemoryReminderRepository(rules: [
            ReminderFixtures.rule(offsetSeconds: 24 * 60 * 60)
        ])
        let scheduler = AppCompositionMockNotificationScheduler(seed: [
            notificationRequest(deliveryDate: DomainTestFactory.date(daysFromReference: 29))
        ])
        let reminderManager = DeadlineNotificationService(
            reminderRepository: reminderRepository,
            scheduler: scheduler,
            clock: FixedClock.standard
        )
        let container = makeRefreshingContainer(
            initialCatalog: [conference()],
            remoteCatalog: [conferenceWithoutDeadlines],
            reminderRepository: reminderRepository,
            reminderManager: reminderManager
        )

        let didRefresh = await container.refreshCatalogInBackground()
        let snapshot = await scheduler.snapshot()
        let rules = try await reminderRepository.loadAll()

        XCTAssertTrue(didRefresh)
        XCTAssertTrue(rules.isEmpty)
        XCTAssertTrue(snapshot.scheduled.isEmpty)
        XCTAssertEqual(snapshot.removedDeadlineIDs, [ReminderFixtures.neuripsPaperDeadlineID])
    }

    func testAcceptedRefreshRemovesTrackedOrphansAndPreservesResolvableConferences() async throws {
        let trackedRepository = InMemoryTrackedConferenceRepository(trackedConferences: [
            DomainTestFactory.tracked("ai-neurips"),
            DomainTestFactory.tracked("graphics-siggraph"),
            DomainTestFactory.tracked("hci-uist"),
            DomainTestFactory.tracked("graphics-acm-mm"),
            DomainTestFactory.tracked("hci-chi")
        ])
        let container = makeRefreshingContainer(
            initialCatalog: ConferenceFixtures.catalog(),
            remoteCatalog: acceptedCatalogForOrphanCleanup(),
            trackedRepository: trackedRepository,
            reminderRepository: InMemoryReminderRepository(),
            reminderManager: SpyReminderManager()
        )

        let didRefresh = await container.refreshCatalogInBackground()
        let tracked = try await trackedRepository.loadAll().map(\.conferenceID)

        XCTAssertTrue(didRefresh)
        XCTAssertEqual(tracked, ["ai-neurips", "graphics-siggraph", "hci-uist"])
    }

    @MainActor
    func testAcceptedRefreshRemovesOrphansFromTrackedListAndCount() async throws {
        let trackedRepository = InMemoryTrackedConferenceRepository(trackedConferences: [
            DomainTestFactory.tracked("ai-neurips"),
            DomainTestFactory.tracked("graphics-acm-mm"),
            DomainTestFactory.tracked("hci-chi")
        ])
        let conferenceRepository = InMemoryConferenceRepository(conferences: ConferenceFixtures.catalog())
        let container = DependencyContainer(
            conferenceRepository: conferenceRepository,
            trackedRepository: trackedRepository,
            reminderRepository: InMemoryReminderRepository(),
            reminderManager: SpyReminderManager(),
            catalogSynchronizer: ConferenceCatalogSynchronizer(
                remoteSource: MockAppCompositionRemoteSource(conferences: acceptedCatalogForOrphanCleanup()),
                conferenceRepository: conferenceRepository,
                clock: FixedClock.standard
            ),
            clock: FixedClock.standard,
            configuration: AppLaunchConfiguration(isUITesting: false, seedScenario: .empty, initialSearchQuery: nil)
        )

        let didRefresh = await container.refreshCatalogInBackground()
        let viewModel = container.makeTrackedConferenceListViewModel()
        await viewModel.load()

        XCTAssertTrue(didRefresh)
        XCTAssertEqual(viewModel.rows.map(\.id), ["ai-neurips"])
        XCTAssertEqual(viewModel.trackingCountText, "1 / 10")
    }

    @MainActor
    func testAcceptedRefreshImmediatelyReloadsTrackedListWithoutStaleExampleRows() async throws {
        let aaai = DomainTestFactory.conference(id: "ai-aaai", abbreviation: "AAAI")
        let trackedRepository = InMemoryTrackedConferenceRepository(trackedConferences: [
            DomainTestFactory.tracked("ai-aaai"),
            DomainTestFactory.tracked("graphics-acm-mm"),
            DomainTestFactory.tracked("hci-chi")
        ])
        let conferenceRepository = InMemoryConferenceRepository(conferences: ConferenceFixtures.catalog())
        let container = DependencyContainer(
            conferenceRepository: conferenceRepository,
            trackedRepository: trackedRepository,
            reminderRepository: InMemoryReminderRepository(),
            reminderManager: SpyReminderManager(),
            catalogSynchronizer: ConferenceCatalogSynchronizer(
                remoteSource: MockAppCompositionRemoteSource(conferences: [aaai]),
                conferenceRepository: conferenceRepository,
                clock: FixedClock.standard
            ),
            clock: FixedClock.standard,
            configuration: AppLaunchConfiguration(isUITesting: false, seedScenario: .empty, initialSearchQuery: nil)
        )
        let viewModel = container.makeTrackedConferenceListViewModel()

        await viewModel.load()
        XCTAssertEqual(Set(viewModel.rows.map(\.id)), ["ai-aaai", "graphics-acm-mm", "hci-chi"])

        let didRefresh = await container.refreshCatalogInBackground()
        await viewModel.load()
        let persistedTracked = try await trackedRepository.loadAll().map(\.conferenceID)

        XCTAssertTrue(didRefresh)
        XCTAssertEqual(viewModel.rows.map(\.id), ["ai-aaai"])
        XCTAssertEqual(viewModel.trackingCountText, "1 / 10")
        XCTAssertEqual(persistedTracked, ["ai-aaai"])
    }

    func testAcceptedRefreshCancelsReminderRulesForRemovedTrackedOrphans() async throws {
        let staleGraphicsDeadlineID = "graphics-acm-mm-2027-paper"
        let staleChiDeadlineID = "hci-chi-2027-paper"
        let reminderRepository = InMemoryReminderRepository(rules: [
            ReminderFixtures.rule(deadlineID: staleGraphicsDeadlineID, offsetSeconds: 24 * 60 * 60),
            ReminderFixtures.rule(deadlineID: staleChiDeadlineID, offsetSeconds: 24 * 60 * 60),
            ReminderFixtures.rule(offsetSeconds: 24 * 60 * 60)
        ])
        let scheduler = AppCompositionMockNotificationScheduler(seed: [
            notificationRequest(deadlineID: staleGraphicsDeadlineID),
            notificationRequest(deadlineID: staleChiDeadlineID),
            notificationRequest(deadlineID: ReminderFixtures.neuripsPaperDeadlineID)
        ])
        let reminderManager = DeadlineNotificationService(
            reminderRepository: reminderRepository,
            scheduler: scheduler,
            clock: FixedClock.standard
        )
        let trackedRepository = InMemoryTrackedConferenceRepository(trackedConferences: [
            DomainTestFactory.tracked("ai-neurips"),
            DomainTestFactory.tracked("graphics-acm-mm"),
            DomainTestFactory.tracked("hci-chi")
        ])
        let container = makeRefreshingContainer(
            initialCatalog: ConferenceFixtures.catalog(),
            remoteCatalog: acceptedCatalogForOrphanCleanup(),
            trackedRepository: trackedRepository,
            reminderRepository: reminderRepository,
            reminderManager: reminderManager
        )

        let didRefresh = await container.refreshCatalogInBackground()
        let rules = try await reminderRepository.loadAll()
        let snapshot = await scheduler.snapshot()

        XCTAssertTrue(didRefresh)
        XCTAssertEqual(rules.map(\.deadlineID), [ReminderFixtures.neuripsPaperDeadlineID])
        XCTAssertTrue(snapshot.removedDeadlineIDs.contains(staleGraphicsDeadlineID))
        XCTAssertTrue(snapshot.removedDeadlineIDs.contains(staleChiDeadlineID))
        XCTAssertFalse(snapshot.scheduled.contains { $0.deadlineID == staleGraphicsDeadlineID })
        XCTAssertFalse(snapshot.scheduled.contains { $0.deadlineID == staleChiDeadlineID })
    }

    func testRefreshFailureAndRejectedRefreshPreserveTrackedOrphans() async throws {
        let failedRefreshTracked = try await preservedTrackedIDsAfterRefresh(
            remoteSource: ThrowingAppCompositionRemoteSource(error: .invalidResponse(500))
        )
        let rejectedRefreshTracked = try await preservedTrackedIDsAfterRefresh(
            remoteSource: ThrowingAppCompositionRemoteSource(error: .incompleteBatch("too small"))
        )

        XCTAssertEqual(failedRefreshTracked, ["ai-neurips", "graphics-acm-mm", "hci-chi"])
        XCTAssertEqual(rejectedRefreshTracked, ["ai-neurips", "graphics-acm-mm", "hci-chi"])
    }

    func testCacheOrSeedFallbackDoesNotRemoveTrackedOrphans() async throws {
        let trackedRepository = InMemoryTrackedConferenceRepository(trackedConferences: [
            DomainTestFactory.tracked("ai-neurips"),
            DomainTestFactory.tracked("graphics-acm-mm"),
            DomainTestFactory.tracked("hci-chi")
        ])
        let container = DependencyContainer(
            conferenceRepository: InMemoryConferenceRepository(conferences: [conference()]),
            trackedRepository: trackedRepository,
            reminderRepository: InMemoryReminderRepository(),
            reminderManager: SpyReminderManager(),
            catalogSynchronizer: StaticCatalogSynchronizer(didRefresh: false),
            clock: FixedClock.standard,
            configuration: AppLaunchConfiguration(isUITesting: false, seedScenario: .empty, initialSearchQuery: nil)
        )

        let didRefresh = await container.refreshCatalogInBackground()
        let tracked = try await trackedRepository.loadAll().map(\.conferenceID)

        XCTAssertFalse(didRefresh)
        XCTAssertEqual(tracked, ["ai-neurips", "graphics-acm-mm", "hci-chi"])
    }

    func testAcceptedRefreshOrphanCleanupIsIdempotent() async throws {
        let trackedRepository = InMemoryTrackedConferenceRepository(trackedConferences: [
            DomainTestFactory.tracked("ai-neurips"),
            DomainTestFactory.tracked("graphics-acm-mm"),
            DomainTestFactory.tracked("hci-chi")
        ])
        let container = makeRefreshingContainer(
            initialCatalog: ConferenceFixtures.catalog(),
            remoteCatalog: acceptedCatalogForOrphanCleanup(),
            trackedRepository: trackedRepository,
            reminderRepository: InMemoryReminderRepository(),
            reminderManager: SpyReminderManager()
        )

        let firstRefresh = await container.refreshCatalogInBackground()
        let afterFirstRefresh = try await trackedRepository.loadAll().map(\.conferenceID)
        let secondRefresh = await container.refreshCatalogInBackground()
        let afterSecondRefresh = try await trackedRepository.loadAll().map(\.conferenceID)

        XCTAssertTrue(firstRefresh)
        XCTAssertTrue(secondRefresh)
        XCTAssertEqual(afterFirstRefresh, ["ai-neurips"])
        XCTAssertEqual(afterSecondRefresh, ["ai-neurips"])
    }

    @MainActor
    func testStartupReconciliationRemovesOrphansWhenAcceptedCatalogAlreadyExists() async throws {
        let aaai = DomainTestFactory.conference(id: "ai-aaai", abbreviation: "AAAI")
        let trackedRepository = InMemoryTrackedConferenceRepository(trackedConferences: [
            DomainTestFactory.tracked("ai-aaai"),
            DomainTestFactory.tracked("graphics-acm-mm"),
            DomainTestFactory.tracked("hci-chi")
        ])
        let conferenceRepository = InMemoryConferenceRepository(
            conferences: [aaai],
            updatedAt: DomainTestFactory.date(daysFromReference: 1)
        )
        let container = DependencyContainer(
            conferenceRepository: conferenceRepository,
            trackedRepository: trackedRepository,
            reminderRepository: InMemoryReminderRepository(),
            reminderManager: SpyReminderManager(),
            catalogSynchronizer: StaticCatalogSynchronizer(didRefresh: false),
            clock: FixedClock.standard,
            configuration: AppLaunchConfiguration(isUITesting: false, seedScenario: .empty, initialSearchQuery: nil)
        )
        let viewModel = container.makeTrackedConferenceListViewModel()

        await container.reconcileTrackedConferencesWithAcceptedCatalogIfPresent()
        await viewModel.load()
        let persistedTracked = try await trackedRepository.loadAll().map(\.conferenceID)

        XCTAssertEqual(persistedTracked, ["ai-aaai"])
        XCTAssertEqual(viewModel.rows.map(\.id), ["ai-aaai"])
        XCTAssertEqual(viewModel.trackingCountText, "1 / 10")
    }

    func testStartupReconciliationDoesNotRemoveOrphansFromSeedOnlyCatalog() async throws {
        let trackedRepository = InMemoryTrackedConferenceRepository(trackedConferences: [
            DomainTestFactory.tracked("graphics-acm-mm"),
            DomainTestFactory.tracked("hci-chi")
        ])
        let conferenceRepository = InMemoryConferenceRepository(
            conferences: [conference()],
            updatedAt: SeedConferenceCatalog.seededAt
        )
        let container = DependencyContainer(
            conferenceRepository: conferenceRepository,
            trackedRepository: trackedRepository,
            reminderRepository: InMemoryReminderRepository(),
            reminderManager: SpyReminderManager(),
            catalogSynchronizer: StaticCatalogSynchronizer(didRefresh: false),
            clock: FixedClock.standard,
            configuration: AppLaunchConfiguration(isUITesting: false, seedScenario: .empty, initialSearchQuery: nil)
        )

        await container.reconcileTrackedConferencesWithAcceptedCatalogIfPresent()
        let persistedTracked = try await trackedRepository.loadAll().map(\.conferenceID)

        XCTAssertEqual(persistedTracked, ["graphics-acm-mm", "hci-chi"])
    }

    private func makeRefreshingContainer(
        initialCatalog: [Conference],
        remoteCatalog: [Conference],
        trackedRepository: InMemoryTrackedConferenceRepository? = nil,
        reminderRepository: InMemoryReminderRepository,
        reminderManager: any DeadlineReminderManaging
    ) -> DependencyContainer {
        let conferenceRepository = InMemoryConferenceRepository(conferences: initialCatalog)
        return DependencyContainer(
            conferenceRepository: conferenceRepository,
            trackedRepository: trackedRepository ?? InMemoryTrackedConferenceRepository(trackedConferences: [
                TrackedConference(conferenceID: "ai-neurips", addedAt: DomainTestFactory.referenceDate)
            ]),
            reminderRepository: reminderRepository,
            reminderManager: reminderManager,
            catalogSynchronizer: ConferenceCatalogSynchronizer(
                remoteSource: MockAppCompositionRemoteSource(conferences: remoteCatalog),
                conferenceRepository: conferenceRepository,
                clock: FixedClock.standard
            ),
            clock: FixedClock.standard,
            configuration: AppLaunchConfiguration(isUITesting: false, seedScenario: .empty, initialSearchQuery: nil)
        )
    }

    private func preservedTrackedIDsAfterRefresh(remoteSource: any ConferenceRemoteSource) async throws -> [String] {
        let trackedRepository = InMemoryTrackedConferenceRepository(trackedConferences: [
            DomainTestFactory.tracked("ai-neurips"),
            DomainTestFactory.tracked("graphics-acm-mm"),
            DomainTestFactory.tracked("hci-chi")
        ])
        let conferenceRepository = InMemoryConferenceRepository(conferences: [conference()])
        let container = DependencyContainer(
            conferenceRepository: conferenceRepository,
            trackedRepository: trackedRepository,
            reminderRepository: InMemoryReminderRepository(),
            reminderManager: SpyReminderManager(),
            catalogSynchronizer: ConferenceCatalogSynchronizer(
                remoteSource: remoteSource,
                conferenceRepository: conferenceRepository,
                clock: FixedClock.standard
            ),
            clock: FixedClock.standard,
            configuration: AppLaunchConfiguration(isUITesting: false, seedScenario: .empty, initialSearchQuery: nil)
        )

        let didRefresh = await container.refreshCatalogInBackground()

        XCTAssertFalse(didRefresh)
        return try await trackedRepository.loadAll().map(\.conferenceID)
    }

    private func acceptedCatalogForOrphanCleanup() -> [Conference] {
        [
            conference(),
            DomainTestFactory.conference(
                id: "graphics-siggraph",
                abbreviation: "SIGGRAPH",
                category: DomainTestFactory.graphics,
                editions: [
                    DomainTestFactory.edition(
                        conferenceID: "graphics-siggraph",
                        year: 2027,
                        deadlines: [
                            DomainTestFactory.deadline(
                                id: "graphics-siggraph-2027-paper",
                                editionID: "graphics-siggraph-2027",
                                date: nil,
                                rawDateValue: "TBD"
                            )
                        ]
                    )
                ]
            ),
            DomainTestFactory.conference(
                id: "hci-uist",
                abbreviation: "UIST",
                category: DomainTestFactory.hci,
                editions: [
                    DomainTestFactory.edition(
                        conferenceID: "hci-uist",
                        deadlines: []
                    )
                ]
            )
        ]
    }

    private func conference(deadline: Deadline = DomainTestFactory.deadline(
        id: ReminderFixtures.neuripsPaperDeadlineID,
        editionID: "ai-neurips-2026",
        type: .paper,
        date: DomainTestFactory.date(daysFromReference: 30)
    )) -> Conference {
        DomainTestFactory.conference(
            id: "ai-neurips",
            editions: [
                DomainTestFactory.edition(
                    conferenceID: "ai-neurips",
                    year: 2026,
                    deadlines: [deadline]
                )
            ]
        )
    }

    private func reminderContext(deadlineDate: Date?) -> DeadlineReminderContext {
        DeadlineReminderContext(
            deadlineID: ReminderFixtures.neuripsPaperDeadlineID,
            conferenceTitle: "NeurIPS Conference on Neural Information Processing Systems",
            deadlineTypeText: "Paper",
            deadlineDate: deadlineDate,
            availability: deadlineDate == nil ? .deadlineToBeDetermined : .available
        )
    }

    private func notificationRequest(deliveryDate: Date) -> DeadlineNotificationRequest {
        notificationRequest(
            deadlineID: ReminderFixtures.neuripsPaperDeadlineID,
            deliveryDate: deliveryDate
        )
    }

    private func notificationRequest(
        deadlineID: String,
        deliveryDate: Date = DomainTestFactory.date(daysFromReference: 29)
    ) -> DeadlineNotificationRequest {
        DeadlineNotificationRequest(
            identifier: "topconf.\(deadlineID).86400",
            deadlineID: deadlineID,
            title: "NeurIPS Paper Deadline is in 1 day",
            body: "Deadline",
            deliveryDate: deliveryDate
        )
    }
}

private struct StaticCatalogSynchronizer: ConferenceCatalogSynchronizing {
    let didRefresh: Bool

    func refreshCatalog() async -> Bool {
        didRefresh
    }
}

private actor SpyReminderManager: DeadlineReminderManaging {
    private var contexts: [DeadlineReminderContext] = []

    func rules(for deadlineID: String) async throws -> [ReminderRule] {
        []
    }

    func saveReminderOffsets(
        _ offsets: Set<TimeInterval>,
        for context: DeadlineReminderContext
    ) async -> ReminderSchedulingResult {
        .savedWithoutScheduling
    }

    func synchronizeReminders(for contexts: [DeadlineReminderContext]) async {
        self.contexts = contexts
    }

    func synchronizedContexts() -> [DeadlineReminderContext] {
        contexts
    }
}

private struct MockAppCompositionRemoteSource: ConferenceRemoteSource {
    let conferences: [Conference]

    func fetchConferences() async throws -> [Conference] {
        conferences
    }
}

private struct ThrowingAppCompositionRemoteSource: ConferenceRemoteSource {
    let error: RemoteCatalogError

    func fetchConferences() async throws -> [Conference] {
        throw error
    }
}

private actor AppCompositionMockNotificationScheduler: NotificationScheduling {
    private var scheduled: [DeadlineNotificationRequest]
    private var removedDeadlineIDs: [String] = []

    init(seed: [DeadlineNotificationRequest] = []) {
        self.scheduled = seed
    }

    func requestAuthorization() async throws -> Bool {
        true
    }

    func authorizationStatus() async -> NotificationAuthorizationPresentationStatus {
        .authorized
    }

    func schedule(_ request: DeadlineNotificationRequest) async throws {
        scheduled.removeAll { $0.identifier == request.identifier }
        scheduled.append(request)
    }

    func remove(identifier: String) async {
        scheduled.removeAll { $0.identifier == identifier }
    }

    func removeAll(for deadlineID: String) async {
        removedDeadlineIDs.append(deadlineID)
        let prefix = NotificationIdentifier.deadlinePrefix(deadlineID: deadlineID)
        scheduled.removeAll { $0.identifier.hasPrefix(prefix) }
    }

    func pendingNotificationRequests() async -> [DeadlineNotificationRequest] {
        scheduled
    }

    func snapshot() -> Snapshot {
        Snapshot(scheduled: scheduled, removedDeadlineIDs: removedDeadlineIDs)
    }

    struct Snapshot {
        let scheduled: [DeadlineNotificationRequest]
        let removedDeadlineIDs: [String]
    }
}
