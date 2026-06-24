import XCTest
@testable import TopConf

final class InMemoryConferenceRepositoryTests: XCTestCase {
    func testInitialStateIsEmpty() async throws {
        let repository = InMemoryConferenceRepository()
        let conferences = try await repository.loadAll()
        let updatedAt = try await repository.lastUpdatedAt()

        XCTAssertEqual(conferences, [])
        XCTAssertNil(updatedAt)
    }

    func testSeededInitializationLoadAllAndLookup() async throws {
        let seed = [ConferenceFixtures.upcomingAIConference(), ConferenceFixtures.multipleDeadlineConference()]
        let repository = InMemoryConferenceRepository(conferences: seed, updatedAt: DomainTestFactory.referenceDate)
        let conferences = try await repository.loadAll()
        let chi = try await repository.conference(id: "hci-chi")
        let missing = try await repository.conference(id: "missing")
        let updatedAt = try await repository.lastUpdatedAt()

        XCTAssertEqual(conferences.map(\.id), ["ai-neurips", "hci-chi"])
        XCTAssertEqual(chi?.abbreviation, "CHI")
        XCTAssertNil(missing)
        XCTAssertEqual(updatedAt, DomainTestFactory.referenceDate)
    }

    func testReplaceAllReplacesOldRecordsAndStoresUpdatedAt() async throws {
        let repository = InMemoryConferenceRepository(conferences: [ConferenceFixtures.upcomingAIConference()])
        let replacement = [ConferenceFixtures.closedConference(), ConferenceFixtures.tbdConference()]
        let updatedAt = DomainTestFactory.date(daysFromReference: 1)

        try await repository.replaceAll(replacement, updatedAt: updatedAt)
        let conferences = try await repository.loadAll()
        let oldConference = try await repository.conference(id: "ai-neurips")
        let lastUpdatedAt = try await repository.lastUpdatedAt()

        XCTAssertEqual(conferences.map(\.id), ["graphics-siggraph", "interdisciplinary-www"])
        XCTAssertNil(oldConference)
        XCTAssertEqual(lastUpdatedAt, updatedAt)
    }

    func testCatalogIsNotCappedAtTrackingLimit() async throws {
        let seed = SeedConferenceCatalog.conferences()
        let repository = InMemoryConferenceRepository(conferences: seed, updatedAt: SeedConferenceCatalog.seededAt)

        let conferences = try await repository.loadAll()
        let beyondLimitConference = try await repository.conference(id: "interdisciplinary-wsdm")

        XCTAssertGreaterThan(seed.count, TrackingPolicy.maximumConferenceCount)
        XCTAssertEqual(conferences.count, seed.count)
        XCTAssertNotNil(beyondLimitConference)
    }

    func testReplacingWithEmptyArrayClearsCatalog() async throws {
        let repository = InMemoryConferenceRepository(conferences: ConferenceFixtures.catalog())

        try await repository.replaceAll([], updatedAt: DomainTestFactory.referenceDate)
        let conferences = try await repository.loadAll()

        XCTAssertEqual(conferences, [])
    }

    func testStableIDsExternalMutationAndDeterministicReturns() async throws {
        var seed = [ConferenceFixtures.multipleDeadlineConference(), ConferenceFixtures.upcomingAIConference()]
        let repository = InMemoryConferenceRepository(conferences: seed)
        seed.append(ConferenceFixtures.closedConference())

        let firstLoad = try await repository.loadAll()
        var mutatedReturn = firstLoad
        mutatedReturn.removeAll()
        let secondLoad = try await repository.loadAll()

        XCTAssertEqual(firstLoad.map(\.id), ["ai-neurips", "hci-chi"])
        XCTAssertEqual(secondLoad.map(\.id), ["ai-neurips", "hci-chi"])
        XCTAssertEqual(firstLoad.map(\.id), firstLoad.map(\.id).sorted())
    }
}
