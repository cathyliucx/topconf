import XCTest
@testable import TopConf

final class DeadlineCalculatorTests: XCTestCase {
    private let calculator = DeadlineCalculator(clock: FixedClock.standard)

    func testRemainingTimeFormatting() {
        XCTAssertEqual(calculator.remainingText(until: DomainTestFactory.date(daysFromReference: 100)), "100 days")
        XCTAssertEqual(calculator.remainingText(until: DomainTestFactory.date(daysFromReference: 3)), "3 days")
        XCTAssertEqual(calculator.remainingText(until: DomainTestFactory.date(daysFromReference: 0, hours: 18)), "18 hours")
        XCTAssertEqual(calculator.remainingText(until: DomainTestFactory.date(daysFromReference: 0, minutes: 45)), "45 min")
        XCTAssertEqual(calculator.remainingText(until: FixedClock.standard.now), "Closed")
        XCTAssertEqual(calculator.remainingText(until: DomainTestFactory.date(daysFromReference: -1)), "Closed")
        XCTAssertEqual(calculator.remainingText(until: nil), "TBD")
    }

    func testDeadlineStatus() {
        XCTAssertEqual(calculator.status(for: DomainTestFactory.date(daysFromReference: 100)), .upcoming)
        XCTAssertEqual(calculator.status(for: DomainTestFactory.date(daysFromReference: 3)), .closingSoon)
        XCTAssertEqual(calculator.status(for: FixedClock.standard.now), .closed)
        XCTAssertEqual(calculator.status(for: DomainTestFactory.date(daysFromReference: -1)), .closed)
        XCTAssertEqual(calculator.status(for: nil), .toBeDetermined)
    }
}
