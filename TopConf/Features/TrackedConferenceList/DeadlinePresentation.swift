import Foundation

struct DeadlinePresentation: Equatable {
    let typeText: String
    let remainingText: String
    let originalDeadlineText: String
    let beijingTimeText: String
    let statusText: String
    let status: DeadlineStatus
    let availability: ConferenceAvailability

    static func make(
        deadline: Deadline?,
        availability: ConferenceAvailability,
        calculator: DeadlineCalculator
    ) -> DeadlinePresentation {
        let status = status(for: deadline, availability: availability, calculator: calculator)
        return DeadlinePresentation(
            typeText: typeText(deadline?.type),
            remainingText: remainingText(deadline: deadline, availability: availability, calculator: calculator),
            originalDeadlineText: originalDeadlineText(deadline: deadline, availability: availability),
            beijingTimeText: beijingTimeText(deadline: deadline, availability: availability),
            statusText: statusText(for: availability, status: status),
            status: status,
            availability: availability
        )
    }

    private static func status(
        for deadline: Deadline?,
        availability: ConferenceAvailability,
        calculator: DeadlineCalculator
    ) -> DeadlineStatus {
        switch availability {
        case .available:
            return calculator.status(for: deadline?.date)
        case .deadlineToBeDetermined:
            return .toBeDetermined
        case .allDeadlinesClosed, .sourceUnavailable:
            return .closed
        }
    }

    private static func remainingText(
        deadline: Deadline?,
        availability: ConferenceAvailability,
        calculator: DeadlineCalculator
    ) -> String {
        switch availability {
        case .available:
            return calculator.remainingText(until: deadline?.date)
        case .deadlineToBeDetermined:
            return "TBD"
        case .allDeadlinesClosed:
            return "Closed"
        case .sourceUnavailable:
            return "Unavailable"
        }
    }

    private static func originalDeadlineText(
        deadline: Deadline?,
        availability: ConferenceAvailability
    ) -> String {
        switch availability {
        case .deadlineToBeDetermined:
            return "Not announced"
        case .sourceUnavailable:
            return "Unavailable"
        case .available, .allDeadlinesClosed:
            guard let deadline else {
                return availability == .allDeadlinesClosed ? "Closed" : "Not announced"
            }
            if let rawDateValue = deadline.rawDateValue, !rawDateValue.isEmpty {
                return rawDateValue
            }
            guard let date = deadline.date else {
                return "Not announced"
            }
            let zoneLabel = deadline.originalTimeZoneIdentifier ?? "UTC"
            let timeZone = timeZone(for: zoneLabel)
            return "\(TopConfDateFormatting.compactDateTime(date, timeZone: timeZone)) \(zoneLabel)"
        }
    }

    private static func beijingTimeText(deadline: Deadline?, availability: ConferenceAvailability) -> String {
        guard availability == .available || availability == .allDeadlinesClosed,
              let date = deadline?.date else {
            return "-"
        }
        return TopConfDateFormatting.beijingTime(date)
    }

    private static func statusText(for availability: ConferenceAvailability, status: DeadlineStatus) -> String {
        switch availability {
        case .available:
            switch status {
            case .upcoming:
                return "Upcoming"
            case .closingSoon:
                return "Closing soon"
            case .closed:
                return "Closed"
            case .toBeDetermined:
                return "TBD"
            }
        case .deadlineToBeDetermined:
            return "TBD"
        case .allDeadlinesClosed:
            return "Closed"
        case .sourceUnavailable:
            return "Source unavailable"
        }
    }

    private static func typeText(_ type: DeadlineType?) -> String {
        switch type {
        case .abstract:
            return "Abstract"
        case .paper:
            return "Paper"
        case .supplementary:
            return "Supplementary"
        case .rebuttal:
            return "Rebuttal"
        case .cameraReady:
            return "Camera ready"
        case .registration:
            return "Registration"
        case .other:
            return "Other"
        case nil:
            return "-"
        }
    }

    private static func timeZone(for identifier: String) -> TimeZone {
        if identifier == "AoE" {
            return TimeZone(secondsFromGMT: -12 * 60 * 60) ?? .gmt
        }
        return TimeZone(identifier: identifier) ?? .gmt
    }
}
