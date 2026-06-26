import XCTest
@testable import TopConf

final class ConferenceCatalogSynchronizerTests: XCTestCase {
    func testSuccessfulRefreshReplacesCatalogWithoutTouchingTrackedRecords() async throws {
        let repository = InMemoryConferenceRepository(conferences: [ConferenceFixtures.closedConference()])
        let trackedRepository = InMemoryTrackedConferenceRepository(trackedConferences: [
            TrackedConference(conferenceID: "hci-chi", addedAt: DomainTestFactory.referenceDate)
        ])
        let remoteConference = ConferenceFixtures.upcomingAIConference()
        let synchronizer = ConferenceCatalogSynchronizer(
            remoteSource: MockConferenceRemoteSource(result: .success([remoteConference])),
            conferenceRepository: repository,
            clock: FixedDateClock(now: DomainTestFactory.date(daysFromReference: 2))
        )

        let didRefresh = await synchronizer.refreshCatalog()
        let catalogIDs = try await repository.loadAll().map(\.id)
        let lastUpdatedAt = try await repository.lastUpdatedAt()
        let trackedIDs = try await trackedRepository.loadAll().map(\.conferenceID)

        XCTAssertTrue(didRefresh)
        XCTAssertEqual(catalogIDs, ["ai-neurips"])
        XCTAssertEqual(lastUpdatedAt, DomainTestFactory.date(daysFromReference: 2))
        XCTAssertEqual(trackedIDs, ["hci-chi"])
    }

    func testFailureLeavesExistingCacheIntact() async throws {
        let existing = ConferenceFixtures.closedConference()
        let repository = InMemoryConferenceRepository(
            conferences: [existing],
            updatedAt: DomainTestFactory.referenceDate
        )
        let synchronizer = ConferenceCatalogSynchronizer(
            remoteSource: MockConferenceRemoteSource(result: .failure(RemoteCatalogError.noUsableConferences)),
            conferenceRepository: repository,
            clock: FixedDateClock(now: DomainTestFactory.date(daysFromReference: 2))
        )

        let didRefresh = await synchronizer.refreshCatalog()
        let catalog = try await repository.loadAll()
        let lastUpdatedAt = try await repository.lastUpdatedAt()

        XCTAssertFalse(didRefresh)
        XCTAssertEqual(catalog, [existing])
        XCTAssertEqual(lastUpdatedAt, DomainTestFactory.referenceDate)
    }

    func testRepeatedSynchronizationIsIdempotentForConferencesEditionsAndDeadlines() async throws {
        let repository = InMemoryConferenceRepository()
        let conference = DomainTestFactory.conference(
            id: "ai-neurips",
            editions: [
                DomainTestFactory.edition(
                    conferenceID: "ai-neurips",
                    year: 2027,
                    deadlines: [
                        DomainTestFactory.deadline(
                            id: "ai-neurips-2027-abstract",
                            editionID: "ai-neurips-2027",
                            type: .abstract,
                            date: DomainTestFactory.date(daysFromReference: 30)
                        ),
                        DomainTestFactory.deadline(
                            id: "ai-neurips-2027-paper",
                            editionID: "ai-neurips-2027",
                            type: .paper,
                            date: DomainTestFactory.date(daysFromReference: 37)
                        )
                    ]
                ),
                DomainTestFactory.edition(
                    conferenceID: "ai-neurips",
                    year: 2028,
                    deadlines: [
                        DomainTestFactory.deadline(
                            id: "ai-neurips-2028-paper",
                            editionID: "ai-neurips-2028",
                            type: .paper,
                            date: DomainTestFactory.date(daysFromReference: 400)
                        )
                    ]
                )
            ]
        )
        let synchronizer = ConferenceCatalogSynchronizer(
            remoteSource: MockConferenceRemoteSource(result: .success([conference, conference])),
            conferenceRepository: repository,
            clock: FixedDateClock(now: DomainTestFactory.referenceDate)
        )

        let firstRefresh = await synchronizer.refreshCatalog()
        let secondRefresh = await synchronizer.refreshCatalog()
        let catalog = try await repository.loadAll()

        XCTAssertTrue(firstRefresh)
        XCTAssertTrue(secondRefresh)
        XCTAssertEqual(catalog.count, 1)
        XCTAssertEqual(catalog.flatMap(\.editions).count, 2)
        XCTAssertEqual(catalog.flatMap(\.editions).flatMap(\.deadlines).count, 3)
        XCTAssertEqual(catalog[0].editions.map(\.id), ["ai-neurips-2027", "ai-neurips-2028"])
        XCTAssertEqual(
            catalog[0].editions.flatMap(\.deadlines).map(\.id),
            ["ai-neurips-2027-abstract", "ai-neurips-2027-paper", "ai-neurips-2028-paper"]
        )
    }

    func testTrackedReferenceResolvesAfterRemoteMetadataAndEditionChanges() async throws {
        let repository = InMemoryConferenceRepository(conferences: [ConferenceFixtures.upcomingAIConference()])
        let trackedRepository = InMemoryTrackedConferenceRepository(trackedConferences: [
            TrackedConference(conferenceID: "ai-neurips", addedAt: DomainTestFactory.referenceDate)
        ])
        let changedConference = DomainTestFactory.conference(
            id: "ai-neurips",
            abbreviation: "NIPS",
            fullName: "Renamed Neural Information Processing Conference",
            category: DomainTestFactory.interdisciplinary,
            rank: .b,
            editions: [
                DomainTestFactory.edition(
                    conferenceID: "ai-neurips",
                    year: 2027,
                    deadlines: [
                        DomainTestFactory.deadline(
                            id: "ai-neurips-2027-paper",
                            editionID: "ai-neurips-2027",
                            type: .paper,
                            date: DomainTestFactory.date(daysFromReference: 120)
                        )
                    ]
                )
            ]
        )
        let synchronizer = ConferenceCatalogSynchronizer(
            remoteSource: MockConferenceRemoteSource(result: .success([changedConference])),
            conferenceRepository: repository,
            clock: FixedDateClock(now: DomainTestFactory.referenceDate)
        )

        let didRefresh = await synchronizer.refreshCatalog()
        let tracked = try await trackedRepository.loadAll()
        let catalog = try await repository.loadAll()
        let resolved = TrackedConferenceResolver(
            deadlineSelectionService: DeadlineSelectionService(clock: FixedClock.standard)
        ).resolve(
            trackedConference: try XCTUnwrap(tracked.first),
            currentConferences: catalog,
            lastKnownConferences: []
        )

        XCTAssertTrue(didRefresh)
        XCTAssertEqual(tracked.map(\.conferenceID), ["ai-neurips"])
        XCTAssertEqual(resolved.conference?.abbreviation, "NIPS")
        XCTAssertEqual(resolved.conference?.category, DomainTestFactory.interdisciplinary)
        XCTAssertEqual(resolved.conference?.ccfRank, .b)
        XCTAssertEqual(resolved.edition?.year, 2027)
        XCTAssertEqual(resolved.primaryDeadline?.id, "ai-neurips-2027-paper")
    }
}

private struct MockConferenceRemoteSource: ConferenceRemoteSource {
    let result: Result<[Conference], Error>

    func fetchConferences() async throws -> [Conference] {
        try result.get()
    }
}
