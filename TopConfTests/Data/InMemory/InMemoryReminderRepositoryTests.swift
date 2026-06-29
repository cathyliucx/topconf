import XCTest
@testable import TopConf

final class InMemoryReminderRepositoryTests: XCTestCase {
    func testInitialStateIsEmpty() async throws {
        let repository = InMemoryReminderRepository()
        let rules = try await repository.rules(for: ReminderFixtures.neuripsPaperDeadlineID)

        XCTAssertEqual(rules, [])
    }

    func testSeededInitializationSaveAndQueryByDeadline() async throws {
        let seed = ReminderFixtures.multipleOffsetsForOneDeadline()
        let repository = InMemoryReminderRepository(rules: seed)
        let other = ReminderFixtures.otherDeadlineRule()

        try await repository.save(other)
        let neuripsRules = try await repository.rules(for: ReminderFixtures.neuripsPaperDeadlineID)
        let chiRules = try await repository.rules(for: ReminderFixtures.chiPaperDeadlineID)

        XCTAssertEqual(neuripsRules.map(\.id), [
            "topconf.ai-neurips-2026-paper.21600",
            "topconf.ai-neurips-2026-paper.259200",
            "topconf.ai-neurips-2026-paper.604800"
        ])
        XCTAssertEqual(chiRules, [other])
    }

    func testDuplicateReminderIDReplacesExistingRule() async throws {
        let repository = InMemoryReminderRepository()
        let original = ReminderFixtures.rule(offsetSeconds: 86_400)
        let replacement = ReminderRule(id: original.id, deadlineID: original.deadlineID, offsetSeconds: 43_200)

        try await repository.save(original)
        try await repository.save(replacement)
        let rules = try await repository.rules(for: original.deadlineID)

        XCTAssertEqual(rules, [replacement])
    }

    func testDeleteOneDeleteMissingAndDeleteAllForDeadline() async throws {
        let repository = InMemoryReminderRepository(rules: ReminderFixtures.multipleOffsetsForOneDeadline() + [
            ReminderFixtures.otherDeadlineRule()
        ])

        try await repository.delete(ruleID: "topconf.ai-neurips-2026-paper.21600")
        try await repository.delete(ruleID: "missing")
        let remainingNeuripsOffsets = try await repository.rules(for: ReminderFixtures.neuripsPaperDeadlineID).map(\.offsetSeconds)

        XCTAssertEqual(remainingNeuripsOffsets, [
            3 * 24 * 60 * 60,
            7 * 24 * 60 * 60
        ])

        try await repository.deleteAll(for: ReminderFixtures.neuripsPaperDeadlineID)
        let neuripsRules = try await repository.rules(for: ReminderFixtures.neuripsPaperDeadlineID)
        let chiRules = try await repository.rules(for: ReminderFixtures.chiPaperDeadlineID)

        XCTAssertEqual(neuripsRules, [])
        XCTAssertEqual(chiRules, [
            ReminderFixtures.otherDeadlineRule()
        ])
    }
}
