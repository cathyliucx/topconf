import Foundation
import UserNotifications

final class UserNotificationScheduler: NotificationScheduling {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    func authorizationStatus() async -> NotificationAuthorizationPresentationStatus {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized:
            return .authorized
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        case .provisional:
            return .provisional
        case .ephemeral:
            return .ephemeral
        @unknown default:
            return .unknown
        }
    }

    func schedule(_ request: DeadlineNotificationRequest) async throws {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        var components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: request.deliveryDate
        )
        components.timeZone = calendar.timeZone
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let notificationRequest = UNNotificationRequest(
            identifier: request.identifier,
            content: content,
            trigger: trigger
        )
        try await center.add(notificationRequest)
    }

    func remove(identifier: String) async {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func removeAll(for deadlineID: String) async {
        let prefix = NotificationIdentifier.deadlinePrefix(deadlineID: deadlineID)
        let identifiers = await center.pendingNotificationRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    func pendingNotificationRequests() async -> [DeadlineNotificationRequest] {
        await center.pendingNotificationRequests().map(Self.makeDeadlineNotificationRequest(from:))
    }

    private static func makeDeadlineNotificationRequest(
        from request: UNNotificationRequest
    ) -> DeadlineNotificationRequest {
        DeadlineNotificationRequest(
            identifier: request.identifier,
            deadlineID: deadlineID(from: request.identifier),
            title: request.content.title,
            body: request.content.body,
            deliveryDate: deliveryDate(from: request.trigger)
        )
    }

    private static func deadlineID(from identifier: String) -> String {
        let parts = identifier.split(separator: ".")
        guard parts.count >= 3, parts.first == "topconf" else {
            return identifier
        }
        return parts.dropFirst().dropLast().joined(separator: ".")
    }

    private static func deliveryDate(from trigger: UNNotificationTrigger?) -> Date {
        if let trigger = trigger as? UNCalendarNotificationTrigger,
           let date = trigger.nextTriggerDate() {
            return date
        }
        return .distantPast
    }
}
