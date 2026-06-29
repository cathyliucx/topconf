import Foundation
import XCTest
@testable import TopConf

final class DeadlineNotificationServiceTests: XCTestCase {
    func testSaveMultipleFutureOffsetsPersistsRulesAndSchedulesDeterministicRequests() async throws {
        let repository = InMemoryReminderRepository()
        let scheduler = MockNotificationScheduler()
        let service = DeadlineNotificationService(
            reminderRepository: repository,
            scheduler: scheduler,
            clock: FixedClock.standard
        )
        let context = reminderContext(deadlineDate: DomainTestFactory.date(daysFromReference: 30))

        let result = await service.saveReminderOffsets(
            [7 * 24 * 60 * 60, 24 * 60 * 60],
            for: context
        )

        XCTAssertEqual(result, .scheduled(count: 2))
        let rules = try await repository.rules(for: context.deadlineID)
        XCTAssertEqual(rules.map(\.id), [
            "topconf.ai-neurips-2026-paper.86400",
            "topconf.ai-neurips-2026-paper.604800"
        ])
        let snapshot = await scheduler.snapshot()
        XCTAssertEqual(snapshot.authorizationRequestCount, 1)
        XCTAssertEqual(snapshot.removedDeadlineIDs, [context.deadlineID])
        XCTAssertEqual(snapshot.scheduled.map(\.identifier), [
            "topconf.ai-neurips-2026-paper.86400",
            "topconf.ai-neurips-2026-paper.604800"
        ])
        XCTAssertEqual(snapshot.scheduled.map(\.body), [
            "Deadline: 2026-07-23 08:00 Beijing Time",
            "Deadline: 2026-07-23 08:00 Beijing Time"
        ])
    }

    func testPastReminderOffsetsAreNotScheduled() async {
        let scheduler = MockNotificationScheduler()
        let service = DeadlineNotificationService(
            reminderRepository: InMemoryReminderRepository(),
            scheduler: scheduler,
            clock: FixedClock.standard
        )
        let context = reminderContext(deadlineDate: DomainTestFactory.date(daysFromReference: 3))

        let result = await service.saveReminderOffsets(
            [7 * 24 * 60 * 60, 24 * 60 * 60],
            for: context
        )

        XCTAssertEqual(result, .scheduled(count: 1))
        let snapshot = await scheduler.snapshot()
        XCTAssertEqual(snapshot.scheduled.map(\.identifier), ["topconf.ai-neurips-2026-paper.86400"])
    }

    func testAuthorizationDeniedPreservesRulesWithoutScheduling() async throws {
        let repository = InMemoryReminderRepository()
        let scheduler = MockNotificationScheduler(isAuthorized: false)
        let service = DeadlineNotificationService(
            reminderRepository: repository,
            scheduler: scheduler,
            clock: FixedClock.standard
        )
        let context = reminderContext(deadlineDate: DomainTestFactory.date(daysFromReference: 30))

        let result = await service.saveReminderOffsets([24 * 60 * 60], for: context)

        XCTAssertEqual(result, .authorizationDenied)
        let rules = try await repository.rules(for: context.deadlineID)
        XCTAssertEqual(rules.map(\.id), ["topconf.ai-neurips-2026-paper.86400"])
        let snapshot = await scheduler.snapshot()
        XCTAssertEqual(snapshot.authorizationRequestCount, 1)
        XCTAssertTrue(snapshot.scheduled.isEmpty)
    }

    func testTBDDeadlineCancelsPendingRequestsAndSavesConfiguration() async throws {
        let repository = InMemoryReminderRepository()
        let scheduler = MockNotificationScheduler()
        let service = DeadlineNotificationService(
            reminderRepository: repository,
            scheduler: scheduler,
            clock: FixedClock.standard
        )
        let context = reminderContext(deadlineDate: nil, availability: .deadlineToBeDetermined)

        let result = await service.saveReminderOffsets([24 * 60 * 60], for: context)

        XCTAssertEqual(result, .savedWithoutScheduling)
        let rules = try await repository.rules(for: context.deadlineID)
        XCTAssertEqual(rules.count, 1)
        let snapshot = await scheduler.snapshot()
        XCTAssertEqual(snapshot.removedDeadlineIDs, [context.deadlineID])
        XCTAssertTrue(snapshot.scheduled.isEmpty)
    }

    func testClearingOffsetsDeletesRulesAndCancelsPendingRequests() async throws {
        let repository = InMemoryReminderRepository()
        try await repository.save(ReminderFixtures.rule(
            deadlineID: ReminderFixtures.neuripsPaperDeadlineID,
            offsetSeconds: 24 * 60 * 60
        ))
        let scheduler = MockNotificationScheduler()
        let service = DeadlineNotificationService(
            reminderRepository: repository,
            scheduler: scheduler,
            clock: FixedClock.standard
        )
        let context = reminderContext(deadlineDate: DomainTestFactory.date(daysFromReference: 30))

        let result = await service.saveReminderOffsets([], for: context)

        XCTAssertEqual(result, .savedWithoutScheduling)
        let rules = try await repository.rules(for: context.deadlineID)
        XCTAssertTrue(rules.isEmpty)
        let snapshot = await scheduler.snapshot()
        XCTAssertEqual(snapshot.removedDeadlineIDs, [context.deadlineID])
        XCTAssertTrue(snapshot.scheduled.isEmpty)
    }

    func testSynchronizeReschedulesExistingRulesWithoutRequestingAuthorization() async throws {
        let repository = InMemoryReminderRepository()
        try await repository.save(ReminderFixtures.rule(
            deadlineID: ReminderFixtures.neuripsPaperDeadlineID,
            offsetSeconds: 24 * 60 * 60
        ))
        let scheduler = MockNotificationScheduler()
        let service = DeadlineNotificationService(
            reminderRepository: repository,
            scheduler: scheduler,
            clock: FixedClock.standard
        )
        let context = reminderContext(deadlineDate: DomainTestFactory.date(daysFromReference: 30))

        await service.synchronizeReminders(for: [context])

        let snapshot = await scheduler.snapshot()
        XCTAssertEqual(snapshot.authorizationRequestCount, 0)
        XCTAssertEqual(snapshot.removedDeadlineIDs, [context.deadlineID])
        XCTAssertEqual(snapshot.scheduled.map(\.identifier), ["topconf.ai-neurips-2026-paper.86400"])
    }

    func testSynchronizeRemovesObsoleteRulesAndNotificationsWhenDeadlineUnavailable() async throws {
        let repository = InMemoryReminderRepository()
        try await repository.save(ReminderFixtures.rule(
            deadlineID: ReminderFixtures.neuripsPaperDeadlineID,
            offsetSeconds: 24 * 60 * 60
        ))
        let scheduler = MockNotificationScheduler()
        let service = DeadlineNotificationService(
            reminderRepository: repository,
            scheduler: scheduler,
            clock: FixedClock.standard
        )

        await service.synchronizeReminders(for: [])

        let rules = try await repository.loadAll()
        XCTAssertTrue(rules.isEmpty)
        let snapshot = await scheduler.snapshot()
        XCTAssertEqual(snapshot.removedDeadlineIDs, [ReminderFixtures.neuripsPaperDeadlineID])
        XCTAssertTrue(snapshot.scheduled.isEmpty)
    }

    private func reminderContext(
        deadlineDate: Date?,
        availability: ConferenceAvailability = .available
    ) -> DeadlineReminderContext {
        DeadlineReminderContext(
            deadlineID: ReminderFixtures.neuripsPaperDeadlineID,
            conferenceTitle: "NeurIPS Conference on Neural Information Processing Systems",
            deadlineTypeText: "Paper",
            deadlineDate: deadlineDate,
            availability: availability
        )
    }
}

private actor MockNotificationScheduler: NotificationScheduling {
    private let isAuthorized: Bool
    private(set) var authorizationRequestCount = 0
    private(set) var scheduled: [DeadlineNotificationRequest] = []
    private(set) var removedIdentifiers: [String] = []
    private(set) var removedDeadlineIDs: [String] = []

    init(isAuthorized: Bool = true) {
        self.isAuthorized = isAuthorized
    }

    func requestAuthorization() async throws -> Bool {
        authorizationRequestCount += 1
        return isAuthorized
    }

    func authorizationStatus() async -> NotificationAuthorizationPresentationStatus {
        isAuthorized ? .authorized : .denied
    }

    func schedule(_ request: DeadlineNotificationRequest) async throws {
        if !scheduled.contains(where: { $0.identifier == request.identifier }) {
            scheduled.append(request)
        }
    }

    func remove(identifier: String) async {
        removedIdentifiers.append(identifier)
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
        Snapshot(
            authorizationRequestCount: authorizationRequestCount,
            scheduled: scheduled,
            removedIdentifiers: removedIdentifiers,
            removedDeadlineIDs: removedDeadlineIDs
        )
    }

    struct Snapshot {
        let authorizationRequestCount: Int
        let scheduled: [DeadlineNotificationRequest]
        let removedIdentifiers: [String]
        let removedDeadlineIDs: [String]
    }
}
