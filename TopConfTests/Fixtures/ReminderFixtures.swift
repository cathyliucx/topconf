import Foundation
@testable import TopConf

enum ReminderFixtures {
    static let neuripsPaperDeadlineID = "ai-neurips-2026-paper"
    static let chiPaperDeadlineID = "hci-chi-2026-paper"

    static func rule(deadlineID: String = neuripsPaperDeadlineID, offsetSeconds: TimeInterval) -> ReminderRule {
        ReminderRule(
            id: "topconf.\(deadlineID).\(Int(offsetSeconds))",
            deadlineID: deadlineID,
            offsetSeconds: offsetSeconds
        )
    }

    static func multipleOffsetsForOneDeadline() -> [ReminderRule] {
        [
            rule(offsetSeconds: 7 * 24 * 60 * 60),
            rule(offsetSeconds: 3 * 24 * 60 * 60),
            rule(offsetSeconds: 6 * 60 * 60)
        ]
    }

    static func otherDeadlineRule() -> ReminderRule {
        rule(deadlineID: chiPaperDeadlineID, offsetSeconds: 24 * 60 * 60)
    }
}
