import XCTest
@testable import TopConf

final class TrackedConferenceResolverTests: XCTestCase {
    private let resolver = TrackedConferenceResolver(
        deadlineSelectionService: DeadlineSelectionService(clock: FixedClock.standard)
    )

    func testNormalFutureResolution() {
        let conference = DomainTestFactory.conference()
        let resolved = resolver.resolve(trackedConference: DomainTestFactory.tracked(conference.id), currentConferences: [conference])

        XCTAssertEqual(resolved.conferenceID, conference.id)
        XCTAssertEqual(resolved.availability, .available)
        XCTAssertEqual(resolved.primaryDeadline?.type, .paper)
    }

    func testTBDClosedAndSourceUnavailableResolution() {
        let tbdConference = DomainTestFactory.conference(editions: [
            DomainTestFactory.edition(deadlines: [
                DomainTestFactory.deadline(date: nil, rawDateValue: "TBD")
            ])
        ])
        let closedConference = DomainTestFactory.conference(id: "hci-chi", abbreviation: "CHI", editions: [
            DomainTestFactory.edition(conferenceID: "hci-chi", deadlines: [
                DomainTestFactory.deadline(editionID: "hci-chi-2026", date: DomainTestFactory.date(daysFromReference: -1))
            ])
        ])

        XCTAssertEqual(resolver.resolve(trackedConference: DomainTestFactory.tracked(tbdConference.id), currentConferences: [tbdConference]).availability, .deadlineToBeDetermined)
        XCTAssertEqual(resolver.resolve(trackedConference: DomainTestFactory.tracked(closedConference.id), currentConferences: [closedConference]).availability, .allDeadlinesClosed)
        XCTAssertEqual(resolver.resolve(trackedConference: DomainTestFactory.tracked("missing"), currentConferences: []).availability, .sourceUnavailable)
    }

    func testLastKnownCacheFallback() {
        let cached = DomainTestFactory.conference(id: "ai-neurips")
        let resolved = resolver.resolve(
            trackedConference: DomainTestFactory.tracked(cached.id),
            currentConferences: [],
            lastKnownConferences: [cached]
        )

        XCTAssertEqual(resolved.conference?.id, cached.id)
        XCTAssertEqual(resolved.availability, .available)
    }

    func testNameRankAndCategoryChangesKeepStableIdentity() {
        let changed = DomainTestFactory.conference(
            id: "ai-neurips",
            abbreviation: "NIPS",
            fullName: "Renamed Conference",
            category: DomainTestFactory.interdisciplinary,
            rank: .b
        )
        let resolved = resolver.resolve(trackedConference: DomainTestFactory.tracked("ai-neurips"), currentConferences: [changed])

        XCTAssertEqual(resolved.conferenceID, "ai-neurips")
        XCTAssertEqual(resolved.conference?.fullName, "Renamed Conference")
        XCTAssertEqual(resolved.conference?.category, DomainTestFactory.interdisciplinary)
        XCTAssertEqual(resolved.conference?.ccfRank, .b)
    }
}
