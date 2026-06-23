import XCTest
@testable import TopConf

final class ConferenceDiscoveryServiceTests: XCTestCase {
    private let service = ConferenceDiscoveryService()

    func testCategoryFilteringAndUnionSemantics() {
        let conferences = sampleConferences()

        XCTAssertEqual(discover(conferences, categories: [DomainTestFactory.ai]).map(\.id), ["ai-neurips"])
        XCTAssertEqual(discover(conferences, categories: [DomainTestFactory.graphics]).map(\.id), ["graphics-siggraph"])
        XCTAssertEqual(discover(conferences, categories: [DomainTestFactory.hci]).map(\.id), ["hci-chi"])
        XCTAssertEqual(discover(conferences, categories: [DomainTestFactory.interdisciplinary]).map(\.id), ["interdisciplinary-www"])
        XCTAssertEqual(discover(conferences, categories: [DomainTestFactory.ai, DomainTestFactory.hci]).map(\.id), ["ai-neurips", "hci-chi"])
    }

    func testRankFilteringAndIntersectionWithCategory() {
        let conferences = sampleConferences()

        XCTAssertEqual(discover(conferences, ranks: [.a]).map(\.id), ["ai-neurips", "hci-chi"])
        XCTAssertEqual(discover(conferences, ranks: [.b]).map(\.id), ["graphics-siggraph"])
        XCTAssertEqual(discover(conferences, ranks: [.a, .b]).map(\.id), ["ai-neurips", "graphics-siggraph", "hci-chi"])
        XCTAssertEqual(discover(conferences, categories: [DomainTestFactory.hci], ranks: [.a]).map(\.id), ["hci-chi"])
        XCTAssertEqual(discover(conferences, categories: [DomainTestFactory.hci], ranks: [.b]).map(\.id), [])
    }

    func testSearchesAbbreviationFullNameYearAndTrimsCase() {
        let conferences = sampleConferences()

        XCTAssertEqual(discover(conferences, query: "  neurips ").map(\.id), ["ai-neurips"])
        XCTAssertEqual(discover(conferences, query: "COMPUTER graphics").map(\.id), ["graphics-siggraph"])
        XCTAssertEqual(discover(conferences, query: "2028").map(\.id), ["interdisciplinary-www"])
        XCTAssertEqual(discover(conferences, query: "").map(\.id), conferences.map(\.id))
    }

    func testUnknownCategoryDoesNotCrashAndTrackingIdentityIsIndependentFromDiscoveryFilters() {
        let unknown = DomainTestFactory.conference(id: "unknown-conf", category: DomainTestFactory.unknown, rank: .unknown)
        let results = discover([unknown], categories: [DomainTestFactory.unknown], ranks: [.unknown])

        XCTAssertEqual(results.map(\.id), ["unknown-conf"])
        XCTAssertEqual(DomainTestFactory.tracked(unknown.id).conferenceID, "unknown-conf")
    }

    private func discover(
        _ conferences: [Conference],
        categories: [ConferenceCategory] = [],
        ranks: Set<CCFRank> = [],
        query: String = ""
    ) -> [Conference] {
        service.discover(
            conferences: conferences,
            filter: ConferenceDiscoveryFilter(
                categorySourceIDs: Set(categories.map(\.sourceID)),
                ranks: ranks,
                query: query
            )
        )
    }

    private func sampleConferences() -> [Conference] {
        [
            DomainTestFactory.conference(id: "ai-neurips", abbreviation: "NeurIPS", category: DomainTestFactory.ai, rank: .a),
            DomainTestFactory.conference(id: "graphics-siggraph", abbreviation: "SIGGRAPH", fullName: "Special Interest Group on Computer Graphics", category: DomainTestFactory.graphics, rank: .b),
            DomainTestFactory.conference(id: "hci-chi", abbreviation: "CHI", category: DomainTestFactory.hci, rank: .a),
            DomainTestFactory.conference(id: "interdisciplinary-www", abbreviation: "WWW", category: DomainTestFactory.interdisciplinary, rank: .c, editions: [
                DomainTestFactory.edition(conferenceID: "interdisciplinary-www", year: 2028)
            ])
        ]
    }
}

