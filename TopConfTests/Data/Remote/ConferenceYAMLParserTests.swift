import XCTest
@testable import TopConf

final class ConferenceYAMLParserTests: XCTestCase {
    func testParsesUpstreamConferenceFieldsAndDeadlines() throws {
        let conference = try ConferenceYAMLParser().parse(
            Self.sampleYAML,
            capturedAt: DomainTestFactory.referenceDate,
            stableID: "ai-aaai"
        )

        XCTAssertEqual(conference.id, "ai-aaai")
        XCTAssertEqual(conference.abbreviation, "AAAI")
        XCTAssertEqual(conference.fullName, "AAAI Conference on Artificial Intelligence")
        XCTAssertEqual(conference.category.sourceID, "AI")
        XCTAssertEqual(conference.category.displayName, "Artificial Intelligence")
        XCTAssertEqual(conference.ccfRank, .a)
        XCTAssertEqual(conference.websiteURL?.absoluteString, "https://aaai.org/2027")
        XCTAssertEqual(conference.lastUpdatedAt, DomainTestFactory.referenceDate)
        XCTAssertEqual(conference.editions.map(\.id), ["aaai27"])
        XCTAssertEqual(conference.editions[0].location, "Montreal")
        XCTAssertEqual(conference.editions[0].deadlines.map(\.type), [.abstract, .paper])
        XCTAssertEqual(conference.editions[0].deadlines[0].rawDateValue, "2026-07-20 23:59:59")
        XCTAssertEqual(conference.editions[0].deadlines[0].originalTimeZoneIdentifier, "GMT-1200")
    }

    func testTBDUnknownCategoryUnknownRankAndInvalidURLAreTolerated() throws {
        let conference = try ConferenceYAMLParser().parse(Self.tbdYAML, stableID: "new-newconf")

        XCTAssertEqual(conference.id, "new-newconf")
        XCTAssertEqual(conference.category.displayName, "NEW")
        XCTAssertEqual(conference.ccfRank, .unknown)
        XCTAssertNil(conference.websiteURL)
        XCTAssertNil(conference.editions[0].deadlines[0].date)
        XCTAssertEqual(conference.editions[0].deadlines[0].rawDateValue, "TBD")
    }

    func testMalformedRootThrowsClearError() {
        XCTAssertThrowsError(try ConferenceYAMLParser().parse("- just\n- a\n- list")) { error in
            XCTAssertEqual(error as? RemoteCatalogError, .malformedRoot)
        }
    }

    func testSourceIdentityKeepsConferenceIDStableAcrossMutableMetadataChanges() throws {
        let parser = ConferenceYAMLParser()
        let original = try parser.parse(Self.sampleYAML, stableID: "ai-aaai")
        let changed = try parser.parse(Self.metadataChangedYAML, stableID: "ai-aaai")

        XCTAssertEqual(original.id, "ai-aaai")
        XCTAssertEqual(changed.id, "ai-aaai")
        XCTAssertEqual(changed.abbreviation, "AAAI-New")
        XCTAssertEqual(changed.category.sourceID, "MX")
        XCTAssertEqual(changed.ccfRank, .b)
        XCTAssertEqual(changed.websiteURL?.absoluteString, "https://aaai.example/new")
        XCTAssertEqual(changed.editions.map(\.conferenceID), ["ai-aaai", "ai-aaai"])
        XCTAssertEqual(changed.editions.map(\.year), [2027, 2028])
    }

    func testTimeZoneParserCoversAoEUTCAndIANAIdentifiers() {
        let parser = DeadlineTimeZoneParser()

        XCTAssertEqual(parser.timeZone(for: "AoE").secondsFromGMT(), -43_200)
        XCTAssertEqual(parser.timeZone(for: "UTC").secondsFromGMT(), 0)
        XCTAssertEqual(parser.timeZone(for: "Asia/Shanghai").identifier, "Asia/Shanghai")
        XCTAssertEqual(parser.timeZone(for: "America/Los_Angeles").identifier, "America/Los_Angeles")
        XCTAssertEqual(parser.timeZone(for: "Not/AZone").secondsFromGMT(), 0)
    }

    private static let sampleYAML = """
    title: AAAI
    description: AAAI Conference on Artificial Intelligence
    sub: AI
    rank:
      ccf: A
    confs:
      - year: 2027
        id: aaai27
        link: https://aaai.org/2027
        timeline:
          - abstract_deadline: '2026-07-20 23:59:59'
            deadline: '2026-07-27 23:59:59'
        timezone: UTC-12
        place: Montreal
    """

    private static let tbdYAML = """
    title: NewConf
    sub: NEW
    rank:
      ccf: Surprise
    confs:
      - year: 2028
        id: new28
        link: not a url
        timeline:
          - deadline: TBD
        timezone: Asia/Shanghai
    """

    private static let metadataChangedYAML = """
    title: AAAI-New
    description: Renamed Artificial Intelligence Conference
    sub: MX
    rank:
      ccf: B
    confs:
      - year: 2027
        id: aaai27
        link: https://aaai.example/old
        timeline:
          - abstract_deadline: '2026-08-20 23:59:59'
            deadline: '2026-08-27 23:59:59'
        timezone: UTC-12
        place: Vancouver
      - year: 2028
        id: aaai28
        link: https://aaai.example/new
        timeline:
          - deadline: '2027-08-27 23:59:59'
        timezone: UTC-12
        place: Singapore
    """
}
