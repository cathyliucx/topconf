import Foundation
import XCTest
@testable import TopConf

@MainActor
final class ReminderViewModelTests: XCTestCase {
    func testLoadReflectsPersistedReminderRules() async {
        let manager = MockReminderManager(
            rules: [ReminderFixtures.rule(offsetSeconds: 7 * 24 * 60 * 60)]
        )
        let viewModel = ReminderViewModel(
            context: context(),
            reminderManager: manager,
            options: ReminderOffsetOption.options(from: [7 * 24 * 60 * 60, 24 * 60 * 60])
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.state, .loaded)
        XCTAssertTrue(viewModel.isSelected(7 * 24 * 60 * 60))
        XCTAssertFalse(viewModel.isSelected(24 * 60 * 60))
    }

    func testToggleUpdatesSelectedOffsetsBeforeSave() {
        let viewModel = ReminderViewModel(
            context: context(),
            reminderManager: MockReminderManager(),
            options: ReminderOffsetOption.options(from: [24 * 60 * 60])
        )

        viewModel.setSelected(true, offset: 24 * 60 * 60)
        XCTAssertTrue(viewModel.isSelected(24 * 60 * 60))

        viewModel.setSelected(false, offset: 24 * 60 * 60)
        XCTAssertFalse(viewModel.isSelected(24 * 60 * 60))
    }

    func testSaveDelegatesSelectedOffsetsAndReportsDeniedAuthorizationRecoverably() async {
        let manager = MockReminderManager(saveResult: .authorizationDenied)
        let viewModel = ReminderViewModel(
            context: context(),
            reminderManager: manager,
            options: ReminderOffsetOption.options(from: [24 * 60 * 60])
        )

        viewModel.setSelected(true, offset: 24 * 60 * 60)
        await viewModel.save()

        let savedOffsets = await manager.savedOffsetsSnapshot()
        XCTAssertEqual(savedOffsets, [24 * 60 * 60])
        XCTAssertEqual(viewModel.state, .loaded)
        XCTAssertEqual(viewModel.message, "Notification permission was denied. Reminder settings were saved.")
    }

    private func context() -> DeadlineReminderContext {
        DeadlineReminderContext(
            deadlineID: ReminderFixtures.neuripsPaperDeadlineID,
            conferenceTitle: "NeurIPS Conference on Neural Information Processing Systems",
            deadlineTypeText: "Paper",
            deadlineDate: DomainTestFactory.date(daysFromReference: 30),
            availability: .available
        )
    }
}

private actor MockReminderManager: DeadlineReminderManaging {
    private let rulesValue: [ReminderRule]
    private let saveResult: ReminderSchedulingResult
    private(set) var savedOffsets: Set<TimeInterval> = []

    init(
        rules: [ReminderRule] = [],
        saveResult: ReminderSchedulingResult = .scheduled(count: 0)
    ) {
        self.rulesValue = rules
        self.saveResult = saveResult
    }

    func rules(for deadlineID: String) async throws -> [ReminderRule] {
        rulesValue.filter { $0.deadlineID == deadlineID }
    }

    func saveReminderOffsets(
        _ offsets: Set<TimeInterval>,
        for context: DeadlineReminderContext
    ) async -> ReminderSchedulingResult {
        savedOffsets = offsets
        return saveResult
    }

    func synchronizeReminders(for contexts: [DeadlineReminderContext]) async {
    }

    func savedOffsetsSnapshot() -> Set<TimeInterval> {
        savedOffsets
    }
}
