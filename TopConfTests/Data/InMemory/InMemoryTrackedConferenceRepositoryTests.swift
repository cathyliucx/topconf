import XCTest
@testable import TopConf

final class InMemoryTrackedConferenceRepositoryTests: XCTestCase {
    func testInitialStateIsEmpty() async throws {
        let repository = InMemoryTrackedConferenceRepository()
        let records = try await repository.loadAll()
        let count = try await repository.count()
        let containsNeurIPS = try await repository.contains(conferenceID: "ai-neurips")

        XCTAssertEqual(records, [])
        XCTAssertEqual(count, 0)
        XCTAssertFalse(containsNeurIPS)
    }

    func testSeededInitializationAddContainsAndCount() async throws {
        let repository = InMemoryTrackedConferenceRepository(trackedConferences: [
            TrackedConferenceFixtures.tracked("hci-chi")
        ])

        try await repository.add(TrackedConferenceFixtures.tracked("ai-neurips"))
        let containsCHI = try await repository.contains(conferenceID: "hci-chi")
        let containsNeurIPS = try await repository.contains(conferenceID: "ai-neurips")
        let count = try await repository.count()
        let records = try await repository.loadAll()

        XCTAssertTrue(containsCHI)
        XCTAssertTrue(containsNeurIPS)
        XCTAssertEqual(count, 2)
        XCTAssertEqual(records.map(\.conferenceID), ["ai-neurips", "hci-chi"])
    }

    func testRemoveAndRemoveMissingDoNotCorruptState() async throws {
        let repository = InMemoryTrackedConferenceRepository(trackedConferences: TrackedConferenceFixtures.firstTen())

        try await repository.remove(conferenceID: "ai-neurips")
        try await repository.remove(conferenceID: "missing")
        let containsNeurIPS = try await repository.contains(conferenceID: "ai-neurips")
        let count = try await repository.count()

        XCTAssertFalse(containsNeurIPS)
        XCTAssertEqual(count, TrackingPolicy.maximumConferenceCount - 1)
    }

    func testDuplicateAddIsIdempotent() async throws {
        let repository = InMemoryTrackedConferenceRepository()
        let tracked = TrackedConferenceFixtures.tracked("ai-neurips")

        try await repository.add(tracked)
        try await repository.add(tracked)
        let records = try await repository.loadAll()
        let count = try await repository.count()

        XCTAssertEqual(records, [tracked])
        XCTAssertEqual(count, 1)
    }

    func testStoresTenAndDoesNotEnforceDomainMaximum() async throws {
        let repository = InMemoryTrackedConferenceRepository()
        let tracked = TrackedConferenceFixtures.trackedCatalog()

        for record in tracked {
            try await repository.add(record)
        }
        let count = try await repository.count()
        let containsEleventh = try await repository.contains(conferenceID: tracked[10].conferenceID)

        XCTAssertGreaterThan(tracked.count, TrackingPolicy.maximumConferenceCount)
        XCTAssertEqual(count, tracked.count)
        XCTAssertTrue(containsEleventh)
    }

    func testReturnedDataDoesNotExposeInternalStorage() async throws {
        let repository = InMemoryTrackedConferenceRepository(trackedConferences: TrackedConferenceFixtures.firstTen())

        var loaded = try await repository.loadAll()
        loaded.removeAll()
        let count = try await repository.count()

        XCTAssertEqual(count, TrackingPolicy.maximumConferenceCount)
    }

    func testTrackedRecordsSurviveUnrelatedCatalogReplacement() async throws {
        let trackedRepository = InMemoryTrackedConferenceRepository(trackedConferences: [
            TrackedConferenceFixtures.tracked("ai-neurips")
        ])
        let conferenceRepository = InMemoryConferenceRepository(conferences: ConferenceFixtures.catalog())

        try await conferenceRepository.replaceAll([ConferenceFixtures.closedConference()], updatedAt: DomainTestFactory.referenceDate)
        let tracked = try await trackedRepository.loadAll()

        XCTAssertEqual(tracked.map(\.conferenceID), ["ai-neurips"])
    }
}
