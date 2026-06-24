import Foundation
import XCTest
@testable import TopConf

#if DEBUG
@MainActor
final class DebugNotificationTestViewModelTests: XCTestCase {
    func testDebugIdentifierUsesDedicatedNamespace() {
        XCTAssertEqual(DebugNotificationTestViewModel.identifierNamespace, "topconf.debug.notification-test")
        XCTAssertTrue(DebugNotificationTestViewModel.testIdentifier.hasPrefix("topconf.debug.notification-test"))
    }

    func testSchedulingCreatesOnePendingTestRequest() async {
        let scheduler = MockDebugNotificationScheduler(status: .authorized)
        let viewModel = makeViewModel(scheduler: scheduler)

        await viewModel.scheduleTestNotificationInTenSeconds()

        let pending = await scheduler.pendingNotificationRequests()
        XCTAssertEqual(pending.map(\.identifier), [DebugNotificationTestViewModel.testIdentifier])
        XCTAssertEqual(viewModel.pendingTestNotificationCount, 1)
    }

    func testRepeatedSchedulingReplacesRatherThanDuplicates() async {
        let scheduler = MockDebugNotificationScheduler(status: .authorized)
        let viewModel = makeViewModel(scheduler: scheduler)

        await viewModel.scheduleTestNotificationInTenSeconds()
        await viewModel.scheduleTestNotificationInTenSeconds()

        let pending = await scheduler.pendingNotificationRequests()
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.identifier, DebugNotificationTestViewModel.testIdentifier)
        let removedIdentifiers = await scheduler.removedIdentifiersSnapshot()
        XCTAssertEqual(removedIdentifiers, [
            DebugNotificationTestViewModel.testIdentifier,
            DebugNotificationTestViewModel.testIdentifier
        ])
    }

    func testPendingInspectionFiltersOnlyDebugTestRequests() async throws {
        let scheduler = MockDebugNotificationScheduler(status: .authorized)
        try await scheduler.schedule(productionReminder())
        try await scheduler.schedule(debugRequest(suffix: ".extra"))
        let viewModel = makeViewModel(scheduler: scheduler)

        await viewModel.listPendingTopConfTestNotifications()

        XCTAssertEqual(viewModel.pendingTestNotificationCount, 1)
    }

    func testProductionReminderIdentifiersAreExcludedFromDebugResults() async throws {
        let scheduler = MockDebugNotificationScheduler(status: .authorized)
        try await scheduler.schedule(productionReminder())
        let viewModel = makeViewModel(scheduler: scheduler)

        await viewModel.listPendingTopConfTestNotifications()

        XCTAssertEqual(viewModel.pendingTestNotificationCount, 0)
        let pending = await scheduler.pendingNotificationRequests()
        XCTAssertTrue(pending.contains(where: {
            $0.identifier == "topconf.ai-neurips-2026-paper.86400"
        }))
    }

    func testCancelRemovesOnlyDebugTestRequest() async throws {
        let scheduler = MockDebugNotificationScheduler(status: .authorized)
        try await scheduler.schedule(productionReminder())
        try await scheduler.schedule(debugRequest())
        let viewModel = makeViewModel(scheduler: scheduler)

        await viewModel.cancelTestNotification()

        let identifiers = await scheduler.pendingNotificationRequests().map(\.identifier).sorted()
        XCTAssertEqual(identifiers, ["topconf.ai-neurips-2026-paper.86400"])
        XCTAssertEqual(viewModel.pendingTestNotificationCount, 0)
    }

    func testClearRemovesAllDebugTestRequestsWithoutRemovingProductionReminders() async throws {
        let scheduler = MockDebugNotificationScheduler(status: .authorized)
        try await scheduler.schedule(productionReminder())
        try await scheduler.schedule(debugRequest())
        try await scheduler.schedule(debugRequest(suffix: ".replacement"))
        let viewModel = makeViewModel(scheduler: scheduler)

        await viewModel.clearAllTopConfTestNotifications()

        let identifiers = await scheduler.pendingNotificationRequests().map(\.identifier)
        XCTAssertEqual(identifiers, ["topconf.ai-neurips-2026-paper.86400"])
        XCTAssertEqual(viewModel.pendingTestNotificationCount, 0)
    }

    func testAuthorizationStatusIsPresentedCorrectly() async {
        let scheduler = MockDebugNotificationScheduler(status: .provisional)
        let viewModel = makeViewModel(scheduler: scheduler)

        await viewModel.refreshAuthorizationStatus()

        XCTAssertEqual(viewModel.authorizationStatus, .provisional)
        XCTAssertEqual(viewModel.authorizationStatus.displayText, "provisional")
    }

    func testDeniedAuthorizationProducesRecoverableFeedbackWithoutScheduling() async {
        let scheduler = MockDebugNotificationScheduler(status: .denied)
        let viewModel = makeViewModel(scheduler: scheduler)

        await viewModel.scheduleTestNotificationInTenSeconds()

        XCTAssertEqual(viewModel.authorizationStatus, .denied)
        XCTAssertEqual(viewModel.pendingTestNotificationCount, 0)
        XCTAssertTrue(viewModel.latestOperationResult.contains("not scheduled"))
    }

    func testNotDeterminedAuthorizationRequestsPermissionBeforeScheduling() async {
        let scheduler = MockDebugNotificationScheduler(status: .notDetermined, requestResult: true)
        let viewModel = makeViewModel(scheduler: scheduler)

        await viewModel.scheduleTestNotificationInTenSeconds()

        let authorizationRequestCount = await scheduler.authorizationRequestCountSnapshot()
        XCTAssertEqual(authorizationRequestCount, 1)
        XCTAssertEqual(viewModel.authorizationStatus, .authorized)
        XCTAssertEqual(viewModel.pendingTestNotificationCount, 1)
    }

    func testDeveloperToolsAvailabilityIsDebugOnly() {
        XCTAssertTrue(DeveloperToolsAvailability.isNotificationTestHarnessAvailable)
    }

    private func makeViewModel(
        scheduler: MockDebugNotificationScheduler
    ) -> DebugNotificationTestViewModel {
        DebugNotificationTestViewModel(
            scheduler: scheduler,
            now: { Date(timeIntervalSince1970: 1_782_172_800) }
        )
    }

    private func debugRequest(suffix: String = "") -> DeadlineNotificationRequest {
        DeadlineNotificationRequest(
            identifier: "\(DebugNotificationTestViewModel.testIdentifier)\(suffix)",
            deadlineID: DebugNotificationTestViewModel.testIdentifier,
            title: "Debug",
            body: "Debug",
            deliveryDate: Date(timeIntervalSince1970: 1_782_172_810)
        )
    }

    private func productionReminder() -> DeadlineNotificationRequest {
        DeadlineNotificationRequest(
            identifier: "topconf.ai-neurips-2026-paper.86400",
            deadlineID: "ai-neurips-2026-paper",
            title: "NeurIPS Paper Deadline",
            body: "Deadline: 2026-07-23 08:00 Beijing Time",
            deliveryDate: Date(timeIntervalSince1970: 1_782_172_810)
        )
    }
}

private actor MockDebugNotificationScheduler: NotificationScheduling {
    private var status: NotificationAuthorizationPresentationStatus
    private let requestResult: Bool
    private var requestsByIdentifier: [String: DeadlineNotificationRequest] = [:]
    private var removedIdentifiers: [String] = []
    private var authorizationRequestCount = 0

    init(status: NotificationAuthorizationPresentationStatus, requestResult: Bool = false) {
        self.status = status
        self.requestResult = requestResult
    }

    func requestAuthorization() async throws -> Bool {
        authorizationRequestCount += 1
        if requestResult {
            status = .authorized
        } else if status == .notDetermined {
            status = .denied
        }
        return requestResult
    }

    func authorizationStatus() async -> NotificationAuthorizationPresentationStatus {
        status
    }

    func schedule(_ request: DeadlineNotificationRequest) async throws {
        requestsByIdentifier[request.identifier] = request
    }

    func remove(identifier: String) async {
        removedIdentifiers.append(identifier)
        requestsByIdentifier.removeValue(forKey: identifier)
    }

    func removeAll(for deadlineID: String) async {
        let prefix = NotificationIdentifier.deadlinePrefix(deadlineID: deadlineID)
        requestsByIdentifier = requestsByIdentifier.filter { !$0.key.hasPrefix(prefix) }
    }

    func pendingNotificationRequests() async -> [DeadlineNotificationRequest] {
        requestsByIdentifier.values.sorted { $0.identifier < $1.identifier }
    }

    func removedIdentifiersSnapshot() -> [String] {
        removedIdentifiers
    }

    func authorizationRequestCountSnapshot() -> Int {
        authorizationRequestCount
    }
}
#endif
