import Foundation

struct ReminderOffsetOption: Identifiable, Equatable {
    let offsetSeconds: TimeInterval
    let title: String

    var id: Int {
        Int(offsetSeconds)
    }

    static func options(from offsets: [TimeInterval] = ReminderPolicy.presetOffsets) -> [ReminderOffsetOption] {
        offsets.map { offset in
            ReminderOffsetOption(offsetSeconds: offset, title: title(for: offset))
        }
    }

    private static func title(for offset: TimeInterval) -> String {
        if offset >= 24 * 60 * 60 {
            let days = Int(offset / (24 * 60 * 60))
            return days == 1 ? "1 day before" : "\(days) days before"
        }

        let hours = Int(offset / (60 * 60))
        return hours == 1 ? "1 hour before" : "\(hours) hours before"
    }
}

enum ReminderViewModelState: Equatable {
    case idle
    case loading
    case loaded
    case saving
    case failed(String)
}

@MainActor
final class ReminderViewModel: ObservableObject {
    @Published private(set) var state: ReminderViewModelState = .idle
    @Published private(set) var selectedOffsets: Set<TimeInterval> = []
    @Published private(set) var message: String?

    let context: DeadlineReminderContext
    let options: [ReminderOffsetOption]

    private let reminderManager: any DeadlineReminderManaging

    init(
        context: DeadlineReminderContext,
        reminderManager: any DeadlineReminderManaging,
        options: [ReminderOffsetOption] = ReminderOffsetOption.options()
    ) {
        self.context = context
        self.reminderManager = reminderManager
        self.options = options
    }

    func load() async {
        state = .loading
        do {
            selectedOffsets = Set(try await reminderManager.rules(for: context.deadlineID).map(\.offsetSeconds))
            message = nil
            state = .loaded
        } catch {
            message = "Could not load reminders."
            state = .failed("Could not load reminders.")
        }
    }

    func isSelected(_ offset: TimeInterval) -> Bool {
        selectedOffsets.contains(offset)
    }

    func setSelected(_ isSelected: Bool, offset: TimeInterval) {
        if isSelected {
            selectedOffsets.insert(offset)
        } else {
            selectedOffsets.remove(offset)
        }
    }

    func save() async {
        state = .saving
        let result = await reminderManager.saveReminderOffsets(selectedOffsets, for: context)
        switch result {
        case .scheduled(let count):
            message = count == 1 ? "1 reminder scheduled." : "\(count) reminders scheduled."
            state = .loaded
        case .savedWithoutScheduling:
            message = selectedOffsets.isEmpty ? "Reminders cleared." : "Reminder settings saved."
            state = .loaded
        case .authorizationDenied:
            message = "Notification permission was denied. Reminder settings were saved."
            state = .loaded
        case .failed:
            message = "Could not save reminders."
            state = .failed("Could not save reminders.")
        }
    }
}
