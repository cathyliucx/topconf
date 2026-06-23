import XCTest
@testable import TopConf

final class SearchServiceTests: XCTestCase {
    private let service = SearchService()

    func testNormalizeLowercasesAndTrimsWithoutMutatingModel() {
        let conference = DomainTestFactory.conference(abbreviation: "NeurIPS")

        XCTAssertEqual(service.normalize("  NeUrIPS \n"), "neurips")
        XCTAssertEqual(conference.abbreviation, "NeurIPS")
    }

    func testSearchesAbbreviationFullNameAndYear() {
        let conferences = [
            DomainTestFactory.conference(id: "ai-neurips", abbreviation: "NeurIPS", fullName: "Neural Information Processing"),
            DomainTestFactory.conference(id: "hci-chi", abbreviation: "CHI", fullName: "Human Factors", editions: [
                DomainTestFactory.edition(conferenceID: "hci-chi", year: 2029)
            ])
        ]

        XCTAssertEqual(service.searchConferences(conferences, query: "neur").map(\.id), ["ai-neurips"])
        XCTAssertEqual(service.searchConferences(conferences, query: " HUMAN ").map(\.id), ["hci-chi"])
        XCTAssertEqual(service.searchConferences(conferences, query: "2029").map(\.id), ["hci-chi"])
        XCTAssertEqual(service.searchConferences(conferences, query: "").map(\.id), ["ai-neurips", "hci-chi"])
    }
}

