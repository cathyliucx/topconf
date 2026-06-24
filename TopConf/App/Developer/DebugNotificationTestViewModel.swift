import Combine
import Foundation

#if DEBUG
@MainActor
final class DebugNotificationTestViewModel: ObservableObject {
    static let identifierNamespace = "topconf.debug.notification-test"
    static let testIdentifier = identifierNamespace

    @Published private(set) var authorizationStatus: NotificationAuthorizationPresentationStatus = .unknown
    @Published private(set) var scheduledIdentifier: String = testIdentifier
    @Published private(set) var scheduledTriggerTime: String = "Not scheduled"
    @Published private(set) var pendingTestNotificationCount: Int = 0
    @Published private(set) var latestOperationResult: String = "Ready"
    @Published private(set) var errorMessage: String?

    private let scheduler: any NotificationScheduling
    private let now: () -> Date

    init(
        scheduler: any NotificationScheduling,
        now: @escaping () -> Date = Date.init
    ) {
        self.scheduler = scheduler
        self.now = now
    }

    func requestPermission() async {
        do {
            let granted = try await scheduler.requestAuthorization()
            authorizationStatus = await scheduler.authorizationStatus()
            latestOperationResult = granted
                ? "Notification permission granted."
                : "Notification permission denied. You can change this in macOS Settings."
            errorMessage = nil
        } catch {
            authorizationStatus = await scheduler.authorizationStatus()
            latestOperationResult = "Notification permission request failed."
            errorMessage = error.localizedDescription
        }
        await refreshPendingTestNotifications()
    }

    func refreshAuthorizationStatus() async {
        authorizationStatus = await scheduler.authorizationStatus()
        latestOperationResult = "Authorization status refreshed."
        errorMessage = nil
    }

    func scheduleTestNotificationInTenSeconds() async {
        await scheduleReplacingExisting(resultPrefix: "Test notification scheduled")
    }

    func replaceExistingTestNotification() async {
        await scheduleReplacingExisting(resultPrefix: "Existing test notification replaced")
    }

    func listPendingTopConfTestNotifications() async {
        await refreshPendingTestNotifications()
        latestOperationResult = "\(pendingTestNotificationCount) pending Debug test notification(s)."
        errorMessage = nil
    }

    func cancelTestNotification() async {
        await scheduler.remove(identifier: Self.testIdentifier)
        await refreshPendingTestNotifications()
        latestOperationResult = "Debug test notification canceled."
        errorMessage = nil
    }

    func clearAllTopConfTestNotifications() async {
        let requests = await pendingDebugRequests()
        for request in requests {
            await scheduler.remove(identifier: request.identifier)
        }
        await refreshPendingTestNotifications()
        latestOperationResult = "All Debug test notifications cleared."
        errorMessage = nil
    }

    private func scheduleReplacingExisting(resultPrefix: String) async {
        do {
            authorizationStatus = await scheduler.authorizationStatus()
            if authorizationStatus == .notDetermined {
                _ = try await scheduler.requestAuthorization()
                authorizationStatus = await scheduler.authorizationStatus()
            }
            guard authorizationStatus == .authorized || authorizationStatus == .provisional || authorizationStatus == .ephemeral else {
                latestOperationResult = "Notification permission is \(authorizationStatus.displayText). Test notification was not scheduled."
                errorMessage = nil
                await refreshPendingTestNotifications()
                return
            }

            await scheduler.remove(identifier: Self.testIdentifier)
            let deliveryDate = now().addingTimeInterval(10)
            let request = DeadlineNotificationRequest(
                identifier: Self.testIdentifier,
                deadlineID: Self.testIdentifier,
                title: "TopConf Notification Test",
                body: "Debug notification scheduled for \(Self.beijingTime(deliveryDate))",
                deliveryDate: deliveryDate
            )
            try await scheduler.schedule(request)
            await refreshPendingTestNotifications()
            scheduledTriggerTime = Self.beijingTime(deliveryDate)
            latestOperationResult = "\(resultPrefix) for \(scheduledTriggerTime)."
            errorMessage = nil
        } catch {
            latestOperationResult = "Could not schedule Debug test notification."
            errorMessage = error.localizedDescription
            await refreshPendingTestNotifications()
        }
    }

    private func refreshPendingTestNotifications() async {
        let requests = await pendingDebugRequests()
        pendingTestNotificationCount = requests.count
        scheduledIdentifier = Self.testIdentifier
        scheduledTriggerTime = requests.first.map { Self.beijingTime($0.deliveryDate) } ?? "Not scheduled"
    }

    private func pendingDebugRequests() async -> [DeadlineNotificationRequest] {
        await scheduler.pendingNotificationRequests()
            .filter { $0.identifier.hasPrefix(Self.identifierNamespace) }
            .sorted { lhs, rhs in
                if lhs.deliveryDate == rhs.deliveryDate {
                    return lhs.identifier < rhs.identifier
                }
                return lhs.deliveryDate < rhs.deliveryDate
            }
    }

    private static func beijingTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return "\(formatter.string(from: date)) Beijing Time"
    }
}

extension NotificationAuthorizationPresentationStatus {
    var displayText: String {
        switch self {
        case .authorized:
            return "authorized"
        case .denied:
            return "denied"
        case .notDetermined:
            return "not determined"
        case .provisional:
            return "provisional"
        case .ephemeral:
            return "ephemeral"
        case .unknown:
            return "unknown"
        }
    }
}
#endif
