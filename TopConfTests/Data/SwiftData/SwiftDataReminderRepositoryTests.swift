import XCTest
@testable import TopConf

final class SwiftDataReminderRepositoryTests: XCTestCase {
    func testInitialStateIsEmpty() async throws {
        let repository = try makeRepository()
        let rules = try await repository.rules(for: ReminderFixtures.neuripsPaperDeadlineID)

        XCTAssertEqual(rules, [])
    }

    func testSaveQueryAndDeterministicOrderByDeadline() async throws {
        let repository = try makeRepository()
        let seed = ReminderFixtures.multipleOffsetsForOneDeadline()

        for rule in seed {
            try await repository.save(rule)
        }
        try await repository.save(ReminderFixtures.otherDeadlineRule())
        let neuripsRules = try await repository.rules(for: ReminderFixtures.neuripsPaperDeadlineID)
        let chiRules = try await repository.rules(for: ReminderFixtures.chiPaperDeadlineID)

        XCTAssertEqual(neuripsRules.map(\.id), [
            "topconf.ai-neurips-2026-paper.21600",
            "topconf.ai-neurips-2026-paper.259200",
            "topconf.ai-neurips-2026-paper.604800"
        ])
        XCTAssertEqual(chiRules, [ReminderFixtures.otherDeadlineRule()])
    }

    func testDuplicateReminderIDReplacesExistingRule() async throws {
        let repository = try makeRepository()
        let original = ReminderFixtures.rule(offsetSeconds: 86_400)
        let replacement = ReminderRule(id: original.id, deadlineID: original.deadlineID, offsetSeconds: 43_200)

        try await repository.save(original)
        try await repository.save(replacement)
        let rules = try await repository.rules(for: original.deadlineID)

        XCTAssertEqual(rules, [replacement])
    }

    func testDeleteOneDeleteMissingAndDeleteAllForDeadline() async throws {
        let repository = try makeRepository()
        for rule in ReminderFixtures.multipleOffsetsForOneDeadline() + [ReminderFixtures.otherDeadlineRule()] {
            try await repository.save(rule)
        }

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
        XCTAssertEqual(chiRules, [ReminderFixtures.otherDeadlineRule()])
    }

    func testRemindersSurviveCatalogReplacementInSharedContainer() async throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let conferenceRepository = SwiftDataConferenceRepository(container: container)
        let reminderRepository = SwiftDataReminderRepository(container: container)

        try await reminderRepository.save(ReminderFixtures.rule(offsetSeconds: 86_400))
        try await conferenceRepository.replaceAll([ConferenceFixtures.closedConference()], updatedAt: DomainTestFactory.referenceDate)
        let reminders = try await reminderRepository.rules(for: ReminderFixtures.neuripsPaperDeadlineID)

        XCTAssertEqual(reminders.map(\.id), ["topconf.ai-neurips-2026-paper.86400"])
    }

    private func makeRepository() throws -> SwiftDataReminderRepository {
        SwiftDataReminderRepository(container: try SwiftDataTestSupport.makeInMemoryContainer())
    }
}
