import Foundation

enum NotificationAuthorizationPresentationStatus: Equatable {
    case authorized
    case denied
    case notDetermined
    case provisional
    case ephemeral
    case unknown
}

protocol NotificationScheduling {
    func requestAuthorization() async throws -> Bool
    func authorizationStatus() async -> NotificationAuthorizationPresentationStatus
    func schedule(_ request: DeadlineNotificationRequest) async throws
    func remove(identifier: String) async
    func removeAll(for deadlineID: String) async
    func pendingNotificationRequests() async -> [DeadlineNotificationRequest]
}
