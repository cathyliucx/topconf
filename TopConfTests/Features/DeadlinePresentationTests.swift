import XCTest
@testable import TopConf

final class DeadlinePresentationTests: XCTestCase {
    func testBeijingTimeUsesExplicitAsiaShanghaiFormatting() {
        let date = Date(timeIntervalSince1970: 1_750_896_000)

        XCTAssertEqual(TopConfDateFormatting.beijingTime(date), "Jun 26, 08:00 Beijing")
    }

    func testOriginalDeadlinePreservesAoELabel() {
        let presentation = DeadlinePresentation.make(
            deadline: deadline(raw: "Jul 11, 23:59 AoE", zone: "AoE"),
            availability: .available,
            calculator: DeadlineCalculator(clock: FixedClock.standard)
        )

        XCTAssertEqual(presentation.originalDeadlineText, "Jul 11, 23:59 AoE")
    }

    func testOriginalDeadlinePreservesIANAIdentifier() {
        let presentation = DeadlinePresentation.make(
            deadline: deadline(raw: "Jun 25, 17:00 America/Los_Angeles", zone: "America/Los_Angeles"),
            availability: .available,
            calculator: DeadlineCalculator(clock: FixedClock.standard)
        )

        XCTAssertEqual(presentation.originalDeadlineText, "Jun 25, 17:00 America/Los_Angeles")
    }

    func testNilDeadlineAndClosedDeadlinePresentation() {
        let calculator = DeadlineCalculator(clock: FixedClock.standard)
        let tbd = DeadlinePresentation.make(deadline: nil, availability: .deadlineToBeDetermined, calculator: calculator)
        let closed = DeadlinePresentation.make(
            deadline: deadline(date: DomainTestFactory.date(daysFromReference: -1), raw: "Jun 22, 23:59 AoE", zone: "AoE"),
            availability: .allDeadlinesClosed,
            calculator: calculator
        )

        XCTAssertEqual(tbd.remainingText, "TBD")
        XCTAssertEqual(tbd.beijingTimeText, "-")
        XCTAssertEqual(closed.remainingText, "Closed")
        XCTAssertEqual(closed.statusText, "Closed")
    }

    func testDayBoundaryAndYearBoundaryConversion() {
        let dayBoundary = utcDate(year: 2026, month: 6, day: 22, hour: 23, minute: 0)
        let yearBoundary = utcDate(year: 2026, month: 12, day: 31, hour: 23, minute: 25)

        XCTAssertEqual(TopConfDateFormatting.beijingTime(dayBoundary), "Jun 23, 07:00 Beijing")
        XCTAssertEqual(TopConfDateFormatting.beijingTime(yearBoundary), "Jan 1, 07:25 Beijing")
    }

    private func utcDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar.date(from: DateComponents(
            timeZone: .gmt,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )) ?? Date(timeIntervalSince1970: 0)
    }

    private func deadline(
        date: Date = DomainTestFactory.date(daysFromReference: 3),
        raw: String?,
        zone: String?
    ) -> Deadline {
        Deadline(
            id: "deadline",
            editionID: "edition",
            type: .paper,
            date: date,
            originalTimeZoneIdentifier: zone,
            rawDateValue: raw,
            comment: nil
        )
    }
}
