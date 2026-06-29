import XCTest
@testable import TopConf

final class SwiftDataTrackedConferenceRepositoryTests: XCTestCase {
    func testInitialStateIsEmpty() async throws {
        let repository = try makeRepository()
        let records = try await repository.loadAll()
        let count = try await repository.count()
        let containsNeurIPS = try await repository.contains(conferenceID: "ai-neurips")

        XCTAssertEqual(records, [])
        XCTAssertEqual(count, 0)
        XCTAssertFalse(containsNeurIPS)
    }

    func testAddContainsRemoveAndDeterministicLoad() async throws {
        let repository = try makeRepository()

        try await repository.add(TrackedConferenceFixtures.tracked("hci-chi"))
        try await repository.add(TrackedConferenceFixtures.tracked("ai-neurips"))
        let containsCHI = try await repository.contains(conferenceID: "hci-chi")
        let count = try await repository.count()
        let records = try await repository.loadAll()

        XCTAssertTrue(containsCHI)
        XCTAssertEqual(count, 2)
        XCTAssertEqual(records.map(\.conferenceID), ["ai-neurips", "hci-chi"])

        try await repository.remove(conferenceID: "hci-chi")
        try await repository.remove(conferenceID: "missing")
        let containsRemoved = try await repository.contains(conferenceID: "hci-chi")
        let remaining = try await repository.loadAll()

        XCTAssertFalse(containsRemoved)
        XCTAssertEqual(remaining.map(\.conferenceID), ["ai-neurips"])
    }

    func testDuplicateAddIsIdempotentAndRepositoryDoesNotEnforceTrackingLimit() async throws {
        let repository = try makeRepository()
        let tracked = TrackedConferenceFixtures.trackedCatalog()

        try await repository.add(tracked[0])
        try await repository.add(tracked[0])
        for record in tracked {
            try await repository.add(record)
        }
        let count = try await repository.count()
        let containsEleventh = try await repository.contains(conferenceID: tracked[10].conferenceID)

        XCTAssertGreaterThan(tracked.count, TrackingPolicy.maximumConferenceCount)
        XCTAssertEqual(count, tracked.count)
        XCTAssertTrue(containsEleventh)
    }

    func testTrackedRecordsSurviveCatalogReplacementInSharedContainer() async throws {
        let container = try SwiftDataTestSupport.makeInMemoryContainer()
        let trackedRepository = SwiftDataTrackedConferenceRepository(container: container)
        let conferenceRepository = SwiftDataConferenceRepository(container: container)

        try await trackedRepository.add(TrackedConferenceFixtures.tracked("ai-neurips"))
        try await conferenceRepository.replaceAll([ConferenceFixtures.closedConference()], updatedAt: DomainTestFactory.referenceDate)
        let tracked = try await trackedRepository.loadAll()

        XCTAssertEqual(tracked.map(\.conferenceID), ["ai-neurips"])
    }

    private func makeRepository() throws -> SwiftDataTrackedConferenceRepository {
        SwiftDataTrackedConferenceRepository(container: try SwiftDataTestSupport.makeInMemoryContainer())
    }
}
