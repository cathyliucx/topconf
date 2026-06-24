import Foundation

enum DeveloperToolsAvailability {
#if DEBUG
    static let isNotificationTestHarnessAvailable = true
#else
    static let isNotificationTestHarnessAvailable = false
#endif
}
