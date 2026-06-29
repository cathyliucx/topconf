import SwiftUI

struct ReminderPopoverView: View {
    @ObservedObject var viewModel: ReminderViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reminders")
                .font(.headline)
                .accessibilityIdentifier("topconf.reminder.popover.\(viewModel.context.deadlineID)")

            VStack(alignment: .leading, spacing: 8) {
                ForEach(viewModel.options) { option in
                    Toggle(
                        option.title,
                        isOn: Binding(
                            get: { viewModel.isSelected(option.offsetSeconds) },
                            set: { viewModel.setSelected($0, offset: option.offsetSeconds) }
                        )
                    )
                    .accessibilityIdentifier("topconf.reminder.offset.\(viewModel.context.deadlineID).\(option.id)")
                }
            }

            if let message = viewModel.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("topconf.reminder.message.\(viewModel.context.deadlineID)")
            }

            HStack {
                Spacer()
                Button("Save") {
                    Task { await viewModel.save() }
                }
                .disabled(viewModel.state == .saving)
                .accessibilityIdentifier("topconf.reminder.save.\(viewModel.context.deadlineID)")
            }
        }
        .padding(14)
        .frame(width: 260)
        .task {
            await viewModel.load()
        }
        .accessibilityIdentifier("topconf.reminder.popover.\(viewModel.context.deadlineID)")
    }
}
