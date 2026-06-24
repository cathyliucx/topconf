import Foundation

final class SilentNotificationScheduler: NotificationScheduling {
    private let isAuthorized: Bool
    private var requestsByIdentifier: [String: DeadlineNotificationRequest] = [:]

    init(isAuthorized: Bool = true) {
        self.isAuthorized = isAuthorized
    }

    func requestAuthorization() async throws -> Bool {
        isAuthorized
    }

    func authorizationStatus() async -> NotificationAuthorizationPresentationStatus {
        isAuthorized ? .authorized : .denied
    }

    func schedule(_ request: DeadlineNotificationRequest) async throws {
        requestsByIdentifier[request.identifier] = request
    }

    func remove(identifier: String) async {
        requestsByIdentifier.removeValue(forKey: identifier)
    }

    func removeAll(for deadlineID: String) async {
        let prefix = NotificationIdentifier.deadlinePrefix(deadlineID: deadlineID)
        requestsByIdentifier = requestsByIdentifier.filter { !$0.key.hasPrefix(prefix) }
    }

    func pendingNotificationRequests() async -> [DeadlineNotificationRequest] {
        requestsByIdentifier.values.sorted { lhs, rhs in
            if lhs.deliveryDate == rhs.deliveryDate {
                return lhs.identifier < rhs.identifier
            }
            return lhs.deliveryDate < rhs.deliveryDate
        }
    }
}
