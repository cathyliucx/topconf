import XCTest
@testable import TopConf

final class ConferenceSortingServiceTests: XCTestCase {
    private let service = ConferenceSortingService()

    func testFutureDeadlinesSortByDateThenAbbreviationAcrossCategoryAndRank() {
        let late = resolved(id: "graphics-siggraph", abbreviation: "SIGGRAPH", category: DomainTestFactory.graphics, rank: .b, days: 10)
        let earlyZ = resolved(id: "hci-zoom", abbreviation: "Zoom", category: DomainTestFactory.hci, rank: .c, days: 2)
        let earlyA = resolved(id: "ai-aaai", abbreviation: "AAAI", category: DomainTestFactory.ai, rank: .a, days: 2)

        XCTAssertEqual(service.sort([late, earlyZ, earlyA]).map(\.conferenceID), ["ai-aaai", "hci-zoom", "graphics-siggraph"])
    }

    func testAvailabilityPriorityAndDeterministicFallback() {
        let unavailable = state(id: "z-unavailable", abbreviation: "Zed", availability: .sourceUnavailable)
        let closed = state(id: "a-closed", abbreviation: "AAA", availability: .allDeadlinesClosed)
        let tbdB = state(id: "b-tbd", abbreviation: "BBB", availability: .deadlineToBeDetermined)
        let tbdA = state(id: "a-tbd", abbreviation: "AAA", availability: .deadlineToBeDetermined)
        let future = resolved(id: "future", abbreviation: "Future", days: 4)

        XCTAssertEqual(service.sort([unavailable, closed, tbdB, future, tbdA]).map(\.conferenceID), ["future", "a-tbd", "b-tbd", "a-closed", "z-unavailable"])
    }

    func testTrackingAndRepositoryOrderDoNotAffectSorting() {
        let firstInput = [resolved(id: "late", abbreviation: "Late", days: 9), resolved(id: "early", abbreviation: "Early", days: 1)]
        let secondInput = Array(firstInput.reversed())

        XCTAssertEqual(service.sort(firstInput).map(\.conferenceID), service.sort(secondInput).map(\.conferenceID))
    }

    private func resolved(
        id: String,
        abbreviation: String,
        category: ConferenceCategory = DomainTestFactory.ai,
        rank: CCFRank = .a,
        days: Int
    ) -> ResolvedTrackedConference {
        let deadline = DomainTestFactory.deadline(editionID: "\(id)-2026", date: DomainTestFactory.date(daysFromReference: days))
        let edition = DomainTestFactory.edition(id: "\(id)-2026", conferenceID: id, deadlines: [deadline])
        let conference = DomainTestFactory.conference(id: id, abbreviation: abbreviation, category: category, rank: rank, editions: [edition])
        return ResolvedTrackedConference(conferenceID: id, conference: conference, edition: edition, primaryDeadline: deadline, availability: .available)
    }

    private func state(id: String, abbreviation: String, availability: ConferenceAvailability) -> ResolvedTrackedConference {
        let conference = DomainTestFactory.conference(id: id, abbreviation: abbreviation)
        return ResolvedTrackedConference(conferenceID: id, conference: conference, edition: nil, primaryDeadline: nil, availability: availability)
    }
}

