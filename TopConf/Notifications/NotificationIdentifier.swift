import Foundation

enum NotificationIdentifier {
    static func reminder(deadlineID: String, offsetSeconds: TimeInterval) -> String {
        "topconf.\(deadlineID).\(Int(offsetSeconds))"
    }

    static func deadlinePrefix(deadlineID: String) -> String {
        "topconf.\(deadlineID)."
    }
}
