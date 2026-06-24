import SwiftUI

#if DEBUG
struct DebugNotificationTestView: View {
    @ObservedObject var viewModel: DebugNotificationTestViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Notification Test")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                statusRow("Authorization", viewModel.authorizationStatus.displayText)
                statusRow("Identifier", viewModel.scheduledIdentifier)
                statusRow("Trigger", viewModel.scheduledTriggerTime)
                statusRow("Pending Debug Tests", "\(viewModel.pendingTestNotificationCount)")
                statusRow("Result", viewModel.latestOperationResult)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("topconf.debug.notifications.error")
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Button("Request Notification Permission") {
                    Task { await viewModel.requestPermission() }
                }
                Button("Refresh Authorization Status") {
                    Task { await viewModel.refreshAuthorizationStatus() }
                }
                Button("Schedule Test Notification in 10 Seconds") {
                    Task { await viewModel.scheduleTestNotificationInTenSeconds() }
                }
                Button("List Pending TopConf Test Notifications") {
                    Task { await viewModel.listPendingTopConfTestNotifications() }
                }
                Button("Replace the Existing Test Notification") {
                    Task { await viewModel.replaceExistingTestNotification() }
                }
                Button("Cancel the Test Notification") {
                    Task { await viewModel.cancelTestNotification() }
                }
                Button("Clear All TopConf Test Notifications") {
                    Task { await viewModel.clearAllTopConfTestNotifications() }
                }
            }
        }
        .padding(18)
        .frame(width: 460)
        .task {
            await viewModel.refreshAuthorizationStatus()
            await viewModel.listPendingTopConfTestNotifications()
        }
        .accessibilityIdentifier("topconf.debug.notifications")
    }

    private func statusRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
                .lineLimit(3)
        }
    }
}
#endif
