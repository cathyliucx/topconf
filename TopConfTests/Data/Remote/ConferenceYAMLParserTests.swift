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

    func testTimeZoneParserCoversAllTimezoneFormsUsedBySupportedUpstreamCategories() throws {
        let parser = DeadlineTimeZoneParser()

        let fixedOffsetCases: [(String, Int)] = [
            ("AoE", -43_200),
            ("UTC-12", -43_200),
            ("UTC", 0),
            ("UTC+0", 0),
            ("UTC+1", 3_600),
            ("UTC+2", 7_200),
            ("UTC+7", 25_200),
            ("UTC+8", 28_800),
            ("UTC+9", 32_400),
            ("UTC-4", -14_400),
            ("UTC-5", -18_000),
            ("UTC-6", -21_600),
            ("UTC-7", -25_200),
            ("UTC-8", -28_800),
            ("UTC-10", -36_000)
        ]
        for (identifier, expectedSeconds) in fixedOffsetCases {
            XCTAssertEqual(try parser.timeZone(for: identifier).secondsFromGMT(), expectedSeconds, identifier)
        }

        XCTAssertEqual(try parser.timeZone(for: "Asia/Shanghai").identifier, "Asia/Shanghai")
        XCTAssertEqual(try parser.timeZone(for: "America/Los_Angeles").identifier, "America/Los_Angeles")

        let pacific = try parser.timeZone(for: "PT")
        XCTAssertEqual(pacific.identifier, "America/Los_Angeles")
        XCTAssertEqual(pacific.secondsFromGMT(for: try Self.date("2026-07-01T00:00:00Z")), -25_200)
        XCTAssertEqual(pacific.secondsFromGMT(for: try Self.date("2026-01-01T00:00:00Z")), -28_800)
    }

    func testInvalidTimezoneIsObservableParseFailure() {
        XCTAssertThrowsError(try DeadlineTimeZoneParser().timeZone(for: "Not/AZone")) { error in
            XCTAssertEqual(error as? RemoteCatalogError, .unsupportedTimeZone("Not/AZone"))
        }

        XCTAssertThrowsError(try ConferenceYAMLParser().parse(Self.invalidTimezoneYAML, stableID: "ai-badconf")) { error in
            XCTAssertEqual(error as? RemoteCatalogError, .unsupportedTimeZone("Not/AZone"))
        }
    }

    func testRepresentativeUpstreamDeadlinesMatchCcfddlSemantics() throws {
        let clock = FixedDateClock(now: try Self.date("2026-06-26T00:00:00Z"))
        let selectionService = DeadlineSelectionService(clock: clock)
        let calculator = DeadlineCalculator(clock: clock)
        let cases: [(id: String, yaml: String, expectedDeadlineID: String, expectedBeijing: String, expectedStatus: DeadlineStatus)] = [
            (
                id: "ai-aaai",
                yaml: Self.upstreamAAAIYAML,
                expectedDeadlineID: "aaai27-abstract",
                expectedBeijing: "Jul 21, 19:59 Beijing",
                expectedStatus: .upcoming
            ),
            (
                id: "ai-acl",
                yaml: Self.upstreamACLYAML,
                expectedDeadlineID: "acl26-paper",
                expectedBeijing: "Jan 6, 19:59 Beijing",
                expectedStatus: .closed
            ),
            (
                id: "ai-cvpr",
                yaml: Self.upstreamCVPRYAML,
                expectedDeadlineID: "cvpr26-paper",
                expectedBeijing: "Nov 14, 19:59 Beijing",
                expectedStatus: .closed
            ),
            (
                id: "ai-iccv",
                yaml: Self.upstreamICCVYAML,
                expectedDeadlineID: "iccv25-paper",
                expectedBeijing: "Mar 8, 17:59 Beijing",
                expectedStatus: .closed
            ),
            (
                id: "ai-iclr",
                yaml: Self.upstreamICLRYAML,
                expectedDeadlineID: "iclr26-paper",
                expectedBeijing: "Sep 25, 19:59 Beijing",
                expectedStatus: .closed
            ),
            (
                id: "ai-icml",
                yaml: Self.upstreamICMLYAML,
                expectedDeadlineID: "icml26-paper",
                expectedBeijing: "Jan 29, 19:59 Beijing",
                expectedStatus: .closed
            ),
            (
                id: "ai-nips",
                yaml: Self.upstreamNIPSYAML,
                expectedDeadlineID: "nips26-paper",
                expectedBeijing: "May 7, 19:59 Beijing",
                expectedStatus: .closed
            ),
            (
                id: "cg-dcc",
                yaml: Self.upstreamDCCYAML,
                expectedDeadlineID: "dcc27-paper",
                expectedBeijing: "Oct 3, 14:59 Beijing",
                expectedStatus: .upcoming
            )
        ]

        for testCase in cases {
            let conference = try ConferenceYAMLParser().parse(testCase.yaml, stableID: testCase.id)
            let selection = selectionService.selectDeadline(for: conference)
            let deadline = try XCTUnwrap(
                selection.primaryDeadline ?? conference.editions.flatMap(\.deadlines).first { $0.id == testCase.expectedDeadlineID },
                testCase.id
            )
            let date = try XCTUnwrap(deadline.date, testCase.id)

            XCTAssertEqual(deadline.id, testCase.expectedDeadlineID, testCase.id)
            XCTAssertEqual(TopConfDateFormatting.beijingTime(date), testCase.expectedBeijing, testCase.id)
            XCTAssertEqual(calculator.status(for: date), testCase.expectedStatus, testCase.id)
        }
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

    private static let invalidTimezoneYAML = """
    title: BadConf
    sub: AI
    rank:
      ccf: A
    confs:
      - year: 2027
        id: bad27
        timeline:
          - deadline: '2026-07-27 23:59:59'
        timezone: Not/AZone
    """

    private static let upstreamAAAIYAML = """
    - title: AAAI
      description: AAAI Conference on Artificial Intelligence
      sub: AI
      rank:
        ccf: A
      confs:
        - year: 2027
          id: aaai27
          timeline:
            - abstract_deadline: '2026-07-20 23:59:59'
              deadline: '2026-07-27 23:59:59'
          timezone: UTC-12
    """

    private static let upstreamACLYAML = """
    - title: ACL
      sub: AI
      rank:
        ccf: A
      confs:
        - year: 2026
          id: acl26
          timeline:
            - deadline: '2026-01-05 23:59:59'
          timezone: UTC-12
    """

    private static let upstreamCVPRYAML = """
    - title: CVPR
      sub: AI
      rank:
        ccf: A
      confs:
        - year: 2026
          id: cvpr26
          timeline:
            - deadline: '2025-11-13 23:59:00'
          timezone: UTC-12
    """

    private static let upstreamICCVYAML = """
    - title: ICCV
      sub: AI
      rank:
        ccf: A
      confs:
        - year: 2025
          id: iccv25
          timeline:
            - deadline: '2025-03-08 09:59:59'
          timezone: UTC+0
    """

    private static let upstreamICLRYAML = """
    - title: ICLR
      sub: AI
      rank:
        ccf: A
      confs:
        - year: 2026
          id: iclr26
          timeline:
            - deadline: '2025-09-24 23:59:59'
          timezone: AoE
    """

    private static let upstreamICMLYAML = """
    - title: ICML
      sub: AI
      rank:
        ccf: A
      confs:
        - year: 2026
          id: icml26
          timeline:
            - deadline: '2026-01-29 11:59:59'
          timezone: UTC+0
    """

    private static let upstreamNIPSYAML = """
    - title: NIPS
      sub: AI
      rank:
        ccf: A
      confs:
        - year: 2026
          id: nips26
          timeline:
            - deadline: '2026-05-07 11:59:00'
          timezone: UTC+0
    """

    private static let upstreamDCCYAML = """
    - title: DCC
      sub: CG
      rank:
        ccf: B
      confs:
        - year: 2027
          id: dcc27
          timeline:
            - deadline: '2026-10-02 23:59:59'
          timezone: PT
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

    private static func date(_ value: String) throws -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return try XCTUnwrap(formatter.date(from: value))
    }
}
