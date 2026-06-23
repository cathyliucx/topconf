import XCTest
@testable import TopConf

final class FixtureValidationTests: XCTestCase {
    func testFixtureIDsAreUniqueStableAndNonEmpty() {
        let catalog = ConferenceFixtures.catalog()
        let conferenceIDs = catalog.map(\.id)
        let editions = catalog.flatMap(\.editions)
        let deadlines = editions.flatMap(\.deadlines)

        XCTAssertEqual(Set(conferenceIDs).count, conferenceIDs.count)
        XCTAssertEqual(Set(editions.map(\.id)).count, editions.count)
        XCTAssertEqual(Set(deadlines.map(\.id)).count, deadlines.count)
        XCTAssertTrue(TrackedConferenceFixtures.trackedCatalog().allSatisfy { !$0.conferenceID.isEmpty })
        XCTAssertGreaterThanOrEqual(catalog.count, 11)
        XCTAssertTrue(conferenceIDs.allSatisfy { !$0.isEmpty && !$0.contains(" ") })
    }

    func testScenarioFixturesMatchFixedClockAssumptions() {
        let multiDeadline = ConferenceFixtures.multipleDeadlineConference()
        let tbd = ConferenceFixtures.tbdConference()
        let closed = ConferenceFixtures.closedConference()

        XCTAssertGreaterThan(multiDeadline.editions[0].deadlines.count, 1)
        XCTAssertLessThan(abstractDeadline(in: multiDeadline)?.date ?? .distantFuture, FixedClock.standard.now)
        XCTAssertGreaterThan(paperDeadline(in: multiDeadline)?.date ?? .distantPast, FixedClock.standard.now)
        XCTAssertTrue(tbd.editions.flatMap(\.deadlines).allSatisfy { $0.date == nil })
        XCTAssertTrue(closed.editions.flatMap(\.deadlines).allSatisfy { ($0.date ?? .distantFuture) < FixedClock.standard.now })
    }

    func testUnknownCategoryAndTimezoneRawDataArePreserved() {
        let unknown = ConferenceFixtures.unknownCategoryConference()
        let aoeDeadline = ConferenceFixtures.upcomingAIConference().editions.flatMap(\.deadlines).first
        let ianaDeadline = ConferenceFixtures.multipleEditionConference().editions.flatMap(\.deadlines).first {
            $0.originalTimeZoneIdentifier == "America/Los_Angeles"
        }

        XCTAssertEqual(unknown.category.sourceID, "upstream-new-area")
        XCTAssertEqual(aoeDeadline?.originalTimeZoneIdentifier, "AoE")
        XCTAssertEqual(aoeDeadline?.rawDateValue, "Sep 21, 2026 23:59 AoE")
        XCTAssertEqual(ianaDeadline?.originalTimeZoneIdentifier, "America/Los_Angeles")
        XCTAssertEqual(ianaDeadline?.rawDateValue, "Aug 7, 2026 23:59 America/Los_Angeles")
    }

    private func abstractDeadline(in conference: Conference) -> Deadline? {
        conference.editions.flatMap(\.deadlines).first { $0.type == .abstract }
    }

    private func paperDeadline(in conference: Conference) -> Deadline? {
        conference.editions.flatMap(\.deadlines).first { $0.type == .paper }
    }
}
