import XCTest
@testable import TopConf

final class ConferenceTrackingServiceTests: XCTestCase {
    private let service = ConferenceTrackingService(clock: FixedClock.standard)

    func testAddingWhenZeroConferencesAreTracked() {
        let conference = DomainTestFactory.conference()

        let mutation = service.add(conferenceID: conference.id, to: [], availableConferences: [conference])

        XCTAssertEqual(mutation.result, .added)
        XCTAssertEqual(mutation.trackedConferences.map(\.conferenceID), [conference.id])
    }

    func testAllowsTenthConferenceAndRejectsEleventh() {
        let conferences = (0..<11).map { DomainTestFactory.conference(id: "ai-conf-\($0)", abbreviation: "C\($0)") }
        let nineTracked = conferences.prefix(9).map { DomainTestFactory.tracked($0.id) }

        let tenth = service.add(conferenceID: conferences[9].id, to: nineTracked, availableConferences: conferences)
        let eleventh = service.add(conferenceID: conferences[10].id, to: tenth.trackedConferences, availableConferences: conferences)

        XCTAssertEqual(tenth.result, .added)
        XCTAssertEqual(tenth.trackedConferences.count, 10)
        XCTAssertEqual(eleventh.result, .limitReached(maximum: TrackingPolicy.maximumConferenceCount))
        XCTAssertEqual(eleventh.trackedConferences.count, 10)
    }

    func testRejectsDuplicateAndMissingConference() {
        let conference = DomainTestFactory.conference()
        let tracked = [DomainTestFactory.tracked(conference.id)]

        XCTAssertEqual(
            service.add(conferenceID: conference.id, to: tracked, availableConferences: [conference]).result,
            .alreadyTracked
        )
        XCTAssertEqual(
            service.add(conferenceID: "missing", to: tracked, availableConferences: [conference]).result,
            .conferenceNotFound
        )
    }

    func testRemovingTrackedAndUntrackedConference() {
        let tracked = [DomainTestFactory.tracked("ai-neurips")]

        let removed = service.remove(conferenceID: "ai-neurips", from: tracked)
        let notTracked = service.remove(conferenceID: "hci-chi", from: tracked)

        XCTAssertEqual(removed.result, .removed)
        XCTAssertTrue(removed.trackedConferences.isEmpty)
        XCTAssertEqual(notTracked.result, .notTracked)
        XCTAssertEqual(notTracked.trackedConferences, tracked)
    }

    func testAddingAgainAfterRemoval() {
        let conference = DomainTestFactory.conference()
        let tracked = [DomainTestFactory.tracked(conference.id)]

        let removed = service.remove(conferenceID: conference.id, from: tracked)
        let readded = service.add(conferenceID: conference.id, to: removed.trackedConferences, availableConferences: [conference])

        XCTAssertEqual(readded.result, .added)
        XCTAssertEqual(readded.trackedConferences.map(\.conferenceID), [conference.id])
    }

    func testTrackingIdentitySurvivesCategoryAndRankChanges() {
        let tracked = [DomainTestFactory.tracked("ai-neurips")]
        let changedCategory = DomainTestFactory.conference(id: "ai-neurips", category: DomainTestFactory.hci, rank: .a)
        let changedRank = DomainTestFactory.conference(id: "ai-neurips", category: DomainTestFactory.ai, rank: .b)

        XCTAssertEqual(
            service.add(conferenceID: changedCategory.id, to: tracked, availableConferences: [changedCategory]).result,
            .alreadyTracked
        )
        XCTAssertEqual(
            service.add(conferenceID: changedRank.id, to: tracked, availableConferences: [changedRank]).result,
            .alreadyTracked
        )
    }
}
