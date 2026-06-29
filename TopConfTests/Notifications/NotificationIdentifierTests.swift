import Foundation
import XCTest
@testable import TopConf

final class NotificationIdentifierTests: XCTestCase {
    func testReminderIdentifierIsDeterministic() {
        let identifier = NotificationIdentifier.reminder(
            deadlineID: "ai-neurips-2026-paper",
            offsetSeconds: 7 * 24 * 60 * 60
        )

        XCTAssertEqual(identifier, "topconf.ai-neurips-2026-paper.604800")
    }

    func testDeadlinePrefixMatchesReminderIdentifierPrefix() {
        XCTAssertEqual(
            NotificationIdentifier.deadlinePrefix(deadlineID: "hci-chi-2026-paper"),
            "topconf.hci-chi-2026-paper."
        )
    }
}
