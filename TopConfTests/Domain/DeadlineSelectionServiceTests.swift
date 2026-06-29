import XCTest
@testable import TopConf

final class DeadlineSelectionServiceTests: XCTestCase {
    private let service = DeadlineSelectionService(clock: FixedClock.standard)

    func testSelectsOneFutureDeadline() {
        let conference = conference(deadlines: [.paper(days: 5)])

        XCTAssertEqual(service.selectDeadline(for: conference).primaryDeadline?.id, "ai-neurips-2026-paper")
    }

    func testSelectsEarliestOfMultipleFutureDeadlinesIgnoringSourceOrder() {
        let conference = conference(deadlines: [.supplementary(days: 20), .paper(days: 3), .abstract(days: 10)])

        XCTAssertEqual(service.selectDeadline(for: conference).primaryDeadline?.type, .paper)
    }

    func testAbstractAndPaperFutureSelectsEarlierAbstract() {
        let conference = conference(deadlines: [.paper(days: 10), .abstract(days: 2)])

        XCTAssertEqual(service.selectDeadline(for: conference).primaryDeadline?.type, .abstract)
    }

    func testAbstractClosedButPaperOpenSelectsPaper() {
        let conference = conference(deadlines: [.abstract(days: -1), .paper(days: 4), .supplementary(days: 8)])

        XCTAssertEqual(service.selectDeadline(for: conference).primaryDeadline?.type, .paper)
    }

    func testAllDeadlinesClosed() {
        let conference = conference(deadlines: [.abstract(days: -10), .paper(days: -2)])

        XCTAssertEqual(service.selectDeadline(for: conference), .closed)
    }

    func testNextEditionWithTBDDeadline() {
        let closed = DomainTestFactory.edition(conferenceID: "ai-neurips", year: 2026, deadlines: [DeadlineSpec.paper(days: -2).deadline])
        let tbd = DomainTestFactory.edition(conferenceID: "ai-neurips", year: 2027, deadlines: [DeadlineSpec.tbd(type: .paper).deadline])
        let conference = DomainTestFactory.conference(editions: [closed, tbd])

        XCTAssertEqual(service.selectDeadline(for: conference), .toBeDetermined(edition: tbd))
    }

    func testMultipleYearsDoNotAssumeLargestYearIsActive() {
        let laterClosed = DomainTestFactory.edition(conferenceID: "ai-neurips", year: 2028, deadlines: [DeadlineSpec.paper(days: -1).deadline])
        let earlierOpen = DomainTestFactory.edition(conferenceID: "ai-neurips", year: 2027, deadlines: [DeadlineSpec.paper(days: 6).deadline])
        let conference = DomainTestFactory.conference(editions: [laterClosed, earlierOpen])

        XCTAssertEqual(service.selectDeadline(for: conference), .future(edition: earlierOpen, deadline: earlierOpen.deadlines[0]))
    }

    func testNoParseableDeadlineIsClosedAndMissingSourceIsUnavailable() {
        let noDeadlines = DomainTestFactory.conference(editions: [
            DomainTestFactory.edition(conferenceID: "ai-neurips", year: 2026, deadlines: [])
        ])

        XCTAssertEqual(service.selectDeadline(for: noDeadlines), .closed)
        XCTAssertEqual(service.selectDeadline(for: nil), .sourceUnavailable)
    }

    private func conference(deadlines: [DeadlineSpec]) -> Conference {
        DomainTestFactory.conference(editions: [
            DomainTestFactory.edition(deadlines: deadlines.map(\.deadline))
        ])
    }
}

private struct DeadlineSpec {
    let deadline: Deadline

    static func abstract(days: Int) -> DeadlineSpec {
        spec(type: .abstract, days: days)
    }

    static func paper(days: Int) -> DeadlineSpec {
        spec(type: .paper, days: days)
    }

    static func supplementary(days: Int) -> DeadlineSpec {
        spec(type: .supplementary, days: days)
    }

    static func tbd(type: DeadlineType) -> DeadlineSpec {
        DeadlineSpec(deadline: DomainTestFactory.deadline(
            id: "ai-neurips-2027-\(type.rawValue)",
            editionID: "ai-neurips-2027",
            type: type,
            date: nil,
            rawDateValue: "TBD"
        ))
    }

    private static func spec(type: DeadlineType, days: Int) -> DeadlineSpec {
        DeadlineSpec(deadline: DomainTestFactory.deadline(
            id: "ai-neurips-2026-\(type.rawValue)",
            editionID: "ai-neurips-2026",
            type: type,
            date: DomainTestFactory.date(daysFromReference: days)
        ))
    }
}
