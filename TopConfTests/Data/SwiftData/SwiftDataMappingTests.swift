import XCTest
@testable import TopConf

final class SwiftDataMappingTests: XCTestCase {
    func testConferenceMappingRoundTripsCatalogFieldsAndNestedDeadlines() throws {
        let conference = ConferenceFixtures.multipleDeadlineConference()
        let entity = ConferenceEntityMapper.makeEntity(from: conference)
        let domain = ConferenceEntityMapper.makeDomain(from: entity)

        XCTAssertEqual(entity.id, conference.id)
        XCTAssertEqual(entity.categorySourceID, conference.category.sourceID)
        XCTAssertEqual(entity.categoryDisplayName, conference.category.displayName)
        XCTAssertEqual(entity.ccfRankRawValue, conference.ccfRank.rawValue)
        XCTAssertEqual(entity.websiteURLString, conference.websiteURL?.absoluteString)
        XCTAssertEqual(domain.id, conference.id)
        XCTAssertEqual(domain.abbreviation, conference.abbreviation)
        XCTAssertEqual(domain.fullName, conference.fullName)
        XCTAssertEqual(domain.category, conference.category)
        XCTAssertEqual(domain.ccfRank, conference.ccfRank)
        XCTAssertEqual(domain.websiteURL, conference.websiteURL)
        XCTAssertEqual(domain.lastUpdatedAt, conference.lastUpdatedAt)
        XCTAssertEqual(domain.editions.map(\.id), conference.editions.map(\.id).sorted())
        XCTAssertEqual(domain.editions.first?.deadlines.map(\.id), conference.editions.first?.deadlines.map(\.id).sorted())
    }

    func testTrackedConferenceMappingRoundTripsStableConferenceID() {
        let tracked = TrackedConferenceFixtures.tracked("ai-neurips")
        let entity = TrackedConferenceEntityMapper.makeEntity(from: tracked)
        let domain = TrackedConferenceEntityMapper.makeDomain(from: entity)

        XCTAssertEqual(entity.conferenceID, "ai-neurips")
        XCTAssertEqual(domain, tracked)
    }

    func testReminderMappingRoundTripsAndUpdatesExistingEntity() {
        let original = ReminderFixtures.rule(offsetSeconds: 86_400)
        let replacement = ReminderRule(
            id: original.id,
            deadlineID: ReminderFixtures.chiPaperDeadlineID,
            offsetSeconds: 43_200
        )
        let entity = ReminderEntityMapper.makeEntity(from: original)

        ReminderEntityMapper.update(entity, from: replacement)
        let domain = ReminderEntityMapper.makeDomain(from: entity)

        XCTAssertEqual(domain, replacement)
        XCTAssertTrue(entity.isEnabled)
    }
}
