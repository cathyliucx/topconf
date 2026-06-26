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

    func testFirstLaunchOfflineFallbackSeedsEmptyCatalogWhenRefreshFails() async throws {
        let conferenceRepository = InMemoryConferenceRepository()
        let trackedRepository = InMemoryTrackedConferenceRepository()
        let reminderRepository = InMemoryReminderRepository(rules: [
            ReminderFixtures.rule(deadlineID: ReminderFixtures.chiPaperDeadlineID, offsetSeconds: 24 * 60 * 60)
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
        XCTAssertTrue(catalog.contains { $0.id == "hci-chi" })
        XCTAssertEqual(tracked.map(\.conferenceID), ["hci-chi"])
        XCTAssertEqual(reminderRules.map(\.id), ["topconf.hci-chi-2026-paper.86400"])
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

    private func makeRefreshingContainer(
        initialCatalog: [Conference],
        remoteCatalog: [Conference],
        reminderRepository: InMemoryReminderRepository,
        reminderManager: any DeadlineReminderManaging
    ) -> DependencyContainer {
        let conferenceRepository = InMemoryConferenceRepository(conferences: initialCatalog)
        return DependencyContainer(
            conferenceRepository: conferenceRepository,
            trackedRepository: InMemoryTrackedConferenceRepository(trackedConferences: [
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
        DeadlineNotificationRequest(
            identifier: "topconf.ai-neurips-2026-paper.86400",
            deadlineID: ReminderFixtures.neuripsPaperDeadlineID,
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
