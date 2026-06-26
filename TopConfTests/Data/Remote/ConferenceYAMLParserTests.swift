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
        XCTAssertEqual(conference.category.sourceID, SeedConferenceCatalog.ai.sourceID)
        XCTAssertEqual(conference.category.displayName, "Artificial Intelligence")
        XCTAssertEqual(conference.ccfRank, .a)
        XCTAssertEqual(conference.websiteURL?.absoluteString, "https://aaai.org/2027")
        XCTAssertEqual(conference.lastUpdatedAt, DomainTestFactory.referenceDate)
        XCTAssertEqual(conference.editions.map(\.id), ["aaai27"])
        XCTAssertEqual(conference.editions[0].location, "Montreal")
        XCTAssertEqual(conference.editions[0].deadlines.map(\.type), [.abstract, .paper])
        XCTAssertEqual(conference.editions[0].deadlines[0].rawDateValue, "2026-07-20 23:59:59")
        XCTAssertEqual(conference.editions[0].deadlines[0].originalTimeZoneIdentifier, "UTC-12")
    }

    func testParsesRealUpstreamArrayRootAndPreservesMultipleEditionsAndDeadlines() throws {
        let records = try ConferenceYAMLParser().parseRecords(
            Self.realisticAAAAIArrayYAML,
            capturedAt: DomainTestFactory.referenceDate,
            stableID: "ai-aaai"
        )
        let conference = try XCTUnwrap(records.first?.conference)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(conference.id, "ai-aaai")
        XCTAssertEqual(conference.category.sourceID, SeedConferenceCatalog.ai.sourceID)
        XCTAssertEqual(conference.ccfRank, .a)
        XCTAssertEqual(conference.editions.map(\.id), ["aaai26", "aaai27"])
        XCTAssertEqual(conference.editions.flatMap(\.deadlines).count, 4)
        XCTAssertEqual(conference.editions[1].deadlines.map(\.rawDateValue), [
            "2026-07-20 23:59:59",
            "2026-07-27 23:59:59"
        ])
    }

    func testAcceptanceConferenceFixturesMapToSupportedCategoriesAndRanks() throws {
        let fixtures: [(String, String, String, ConferenceCategory)] = [
            ("ai-aaai", "AAAI", "AI", SeedConferenceCatalog.ai),
            ("ai-icml", "ICML", "AI", SeedConferenceCatalog.ai),
            ("ai-acl", "ACL", "AI", SeedConferenceCatalog.ai),
            ("ai-cvpr", "CVPR", "AI", SeedConferenceCatalog.ai),
            ("ai-iccv", "ICCV", "AI", SeedConferenceCatalog.ai),
            ("cg-vis", "IEEE VIS", "CG", SeedConferenceCatalog.graphics),
            ("cg-vr", "IEEE VR", "CG", SeedConferenceCatalog.graphics),
            ("hi-ubicomp", "UbiComp/ISWC", "HI", SeedConferenceCatalog.hci),
            ("hi-cscw", "CSCW", "HI", SeedConferenceCatalog.hci),
            ("mx-rtss", "RTSS", "MX", SeedConferenceCatalog.interdisciplinary)
        ]

        for (stableID, title, rawCategory, expectedCategory) in fixtures {
            let yaml = Self.singleRecordArrayYAML(title: title, category: rawCategory)
            let conference = try ConferenceYAMLParser().parse(yaml, stableID: stableID)
            XCTAssertEqual(conference.id, stableID)
            XCTAssertEqual(conference.category, expectedCategory)
            XCTAssertEqual(conference.ccfRank, .a)
            XCTAssertEqual(conference.editions.count, 2)
            XCTAssertEqual(conference.editions.flatMap(\.deadlines).count, 3)
        }
    }

    func testKDDDatabaseCategoryIsUnsupportedAndNotEmerging() throws {
        let records = try ConferenceYAMLParser().parseRecords(Self.kddArrayYAML, stableID: "db-sigkdd")

        XCTAssertEqual(records.count, 1)
        XCTAssertNil(records[0].conference)
        XCTAssertEqual(
            records[0].mappingResult,
            .unsupported(rawValue: "DB", displayName: "Database / Data Mining / Information Retrieval")
        )
    }

    func testSupportedTBDUnknownRankAndInvalidURLAreTolerated() throws {
        let conference = try ConferenceYAMLParser().parse(Self.tbdYAML, stableID: "ai-newconf")

        XCTAssertEqual(conference.id, "ai-newconf")
        XCTAssertEqual(conference.category.sourceID, SeedConferenceCatalog.ai.sourceID)
        XCTAssertEqual(conference.ccfRank, .unknown)
        XCTAssertNil(conference.websiteURL)
        XCTAssertNil(conference.editions[0].deadlines[0].date)
        XCTAssertEqual(conference.editions[0].deadlines[0].rawDateValue, "TBD")
    }

    func testUnknownCategoryIsReportedWithoutProducingSupportedConference() throws {
        XCTAssertThrowsError(try ConferenceYAMLParser().parse(Self.unknownCategoryYAML, stableID: "new-newconf")) { error in
            XCTAssertEqual(error as? RemoteCatalogError, .malformedRoot)
        }

        let records = try ConferenceYAMLParser().parseRecords(Self.unknownCategoryYAML, stableID: "new-newconf")
        XCTAssertEqual(records.count, 1)
        XCTAssertNil(records[0].conference)
        XCTAssertEqual(records[0].mappingResult, .unsupported(rawValue: "NEW", displayName: "NEW"))
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
        XCTAssertEqual(changed.category.sourceID, SeedConferenceCatalog.interdisciplinary.sourceID)
        XCTAssertEqual(changed.ccfRank, .b)
        XCTAssertEqual(changed.websiteURL?.absoluteString, "https://aaai.example/new")
        XCTAssertEqual(changed.editions.map(\.conferenceID), ["ai-aaai", "ai-aaai"])
        XCTAssertEqual(changed.editions.map(\.year), [2027, 2028])
    }

    func testTimeZoneParserCoversAoEUTCAndIANAIdentifiers() {
        let parser = DeadlineTimeZoneParser()

        XCTAssertEqual(parser.timeZone(for: "AoE").secondsFromGMT(), -43_200)
        XCTAssertEqual(parser.timeZone(for: "UTC").secondsFromGMT(), 0)
        XCTAssertEqual(parser.timeZone(for: "UTC+0").secondsFromGMT(), 0)
        XCTAssertEqual(parser.timeZone(for: "UTC-8").secondsFromGMT(), -28_800)
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
    sub: AI
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

    private static let unknownCategoryYAML = """
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

    private static let realisticAAAAIArrayYAML = """
    - title: AAAI
      description: AAAI Conference on Artificial Intelligence
      sub: AI
      rank:
        ccf: A
      confs:
        - year: 2026
          id: aaai26
          link: https://aaai.org/conference/aaai/aaai-26/
          timeline:
            - abstract_deadline: '2025-07-25 23:59:59'
              deadline: '2025-08-01 23:59:59'
          timezone: UTC-12
        - year: 2027
          id: aaai27
          link: https://aaai.org/conference/aaai/aaai-27/
          timeline:
            - abstract_deadline: '2026-07-20 23:59:59'
              deadline: '2026-07-27 23:59:59'
          timezone: UTC-12
    """

    private static let kddArrayYAML = """
    - title: SIGKDD
      description: ACM Knowledge Discovery and Data Mining
      sub: DB
      rank:
        ccf: A
      confs:
        - year: 2027
          id: sigkdd27
          link: https://kdd2027.kdd.org/
          timeline:
            - deadline: '2026-07-26 23:59:59'
          timezone: AoE
    """

    private static func singleRecordArrayYAML(title: String, category: String) -> String {
        """
        - title: \(title)
          description: \(title) Conference
          sub: \(category)
          rank:
            ccf: A
          confs:
            - year: 2026
              id: \(title.lowercased().filter(\.isLetter))26
              link: https://example.test/\(title)
              timeline:
                - deadline: '2025-01-01 23:59:59'
              timezone: AoE
            - year: 2027
              id: \(title.lowercased().filter(\.isLetter))27
              link: https://example.test/\(title)-2027
              timeline:
                - abstract_deadline: '2026-07-20 23:59:59'
                  deadline: '2026-07-27 23:59:59'
              timezone: America/Los_Angeles
        """
    }
}
