import XCTest
@testable import TopConf

final class SwiftDataConferenceRepositoryTests: XCTestCase {
    func testInitialStateIsEmpty() async throws {
        let repository = try makeRepository()
        let conferences = try await repository.loadAll()
        let updatedAt = try await repository.lastUpdatedAt()

        XCTAssertEqual(conferences, [])
        XCTAssertNil(updatedAt)
    }

    func testReplaceAllLoadsLookupAndStoresUpdatedAt() async throws {
        let repository = try makeRepository()
        let replacement = [ConferenceFixtures.closedConference(), ConferenceFixtures.tbdConference()]
        let updatedAt = DomainTestFactory.date(daysFromReference: 1)

        try await repository.replaceAll(replacement, updatedAt: updatedAt)
        let conferences = try await repository.loadAll()
        let siggraph = try await repository.conference(id: "graphics-siggraph")
        let missing = try await repository.conference(id: "missing")
        let lastUpdatedAt = try await repository.lastUpdatedAt()

        XCTAssertEqual(conferences.map(\.id), ["graphics-siggraph", "interdisciplinary-www"])
        XCTAssertEqual(siggraph?.abbreviation, "SIGGRAPH")
        XCTAssertNil(missing)
        XCTAssertEqual(lastUpdatedAt, updatedAt)
    }

    func testCatalogIsNotCappedAtTrackingLimit() async throws {
        let repository = try makeRepository()
        let seed = SeedConferenceCatalog.conferences()

        try await repository.replaceAll(seed, updatedAt: SeedConferenceCatalog.seededAt)
        let conferences = try await repository.loadAll()
        let beyondLimitConference = try await repository.conference(id: "interdisciplinary-wsdm")

        XCTAssertGreaterThan(seed.count, TrackingPolicy.maximumConferenceCount)
        XCTAssertEqual(conferences.count, seed.count)
        XCTAssertNotNil(beyondLimitConference)
    }

    func testReplaceAllRemovesStaleCatalogRowsButPreservesTrackedAndReminders() async throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let conferenceRepository = SwiftDataConferenceRepository(container: container)
        let trackedRepository = SwiftDataTrackedConferenceRepository(container: container)
        let reminderRepository = SwiftDataReminderRepository(container: container)

        try await conferenceRepository.replaceAll(ConferenceFixtures.catalog(), updatedAt: DomainTestFactory.referenceDate)
        try await trackedRepository.add(TrackedConferenceFixtures.tracked("ai-neurips"))
        try await reminderRepository.save(ReminderFixtures.rule(offsetSeconds: 86_400))

        try await conferenceRepository.replaceAll([ConferenceFixtures.closedConference()], updatedAt: DomainTestFactory.date(daysFromReference: 2))
        let conferences = try await conferenceRepository.loadAll()
        let staleConference = try await conferenceRepository.conference(id: "ai-neurips")
        let tracked = try await trackedRepository.loadAll()
        let reminders = try await reminderRepository.rules(for: ReminderFixtures.neuripsPaperDeadlineID)

        XCTAssertEqual(conferences.map(\.id), ["interdisciplinary-www"])
        XCTAssertNil(staleConference)
        XCTAssertEqual(tracked.map(\.conferenceID), ["ai-neurips"])
        XCTAssertEqual(reminders.map(\.id), ["topconf.ai-neurips-2026-paper.86400"])
    }

    func testReplacingWithEmptyArrayClearsCatalogAndRetainsMetadata() async throws {
        let repository = try makeRepository()

        try await repository.replaceAll(ConferenceFixtures.catalog(), updatedAt: DomainTestFactory.referenceDate)
        try await repository.replaceAll([], updatedAt: DomainTestFactory.date(daysFromReference: 3))
        let conferences = try await repository.loadAll()
        let updatedAt = try await repository.lastUpdatedAt()

        XCTAssertEqual(conferences, [])
        XCTAssertEqual(updatedAt, DomainTestFactory.date(daysFromReference: 3))
    }

    func testStableIDsAndDeterministicReturns() async throws {
        let repository = try makeRepository()
        let seed = [
            ConferenceFixtures.multipleDeadlineConference(),
            ConferenceFixtures.upcomingAIConference(),
            ConferenceFixtures.renamedNeurIPS()
        ]

        try await repository.replaceAll(seed, updatedAt: DomainTestFactory.referenceDate)
        let conferences = try await repository.loadAll()
        let neurips = try await repository.conference(id: "ai-neurips")

        XCTAssertEqual(conferences.map(\.id), ["ai-neurips", "hci-chi"])
        XCTAssertEqual(neurips?.abbreviation, "NIPS")
        XCTAssertEqual(conferences.map(\.id), conferences.map(\.id).sorted())
    }

    private func makeRepository() throws -> SwiftDataConferenceRepository {
        SwiftDataConferenceRepository(container: try SwiftDataTestSupport.makeInMemoryContainer())
    }
}
