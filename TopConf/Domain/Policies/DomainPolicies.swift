import Foundation

enum TrackingPolicy {
    static let maximumConferenceCount = 10
}

enum DeadlineUrgencyPolicy {
    static let closingSoonInterval: TimeInterval = 7 * 24 * 60 * 60
}

enum ReminderPolicy {
    static let presetOffsets: [TimeInterval] = [
        90 * 24 * 60 * 60,
        60 * 24 * 60 * 60,
        30 * 24 * 60 * 60,
        14 * 24 * 60 * 60,
        7 * 24 * 60 * 60,
        3 * 24 * 60 * 60,
        24 * 60 * 60,
        6 * 60 * 60
    ]
}
