import Foundation

protocol DeadlineReminderManaging {
    func rules(for deadlineID: String) async throws -> [ReminderRule]
    func saveReminderOffsets(
        _ offsets: Set<TimeInterval>,
        for context: DeadlineReminderContext
    ) async -> ReminderSchedulingResult
    func synchronizeReminders(for contexts: [DeadlineReminderContext]) async
}

struct DeadlineReminderContext: Equatable {
    let deadlineID: String
    let conferenceTitle: String
    let deadlineTypeText: String
    let deadlineDate: Date?
    let availability: ConferenceAvailability
}

enum ReminderSchedulingResult: Equatable {
    case scheduled(count: Int)
    case savedWithoutScheduling
    case authorizationDenied
    case failed(String)
}

final class DeadlineNotificationService: DeadlineReminderManaging {
    private let reminderRepository: any ReminderRepository
    private let scheduler: any NotificationScheduling
    private let clock: any Clock

    init(
        reminderRepository: any ReminderRepository,
        scheduler: any NotificationScheduling,
        clock: any Clock
    ) {
        self.reminderRepository = reminderRepository
        self.scheduler = scheduler
        self.clock = clock
    }

    func rules(for deadlineID: String) async throws -> [ReminderRule] {
        try await reminderRepository.rules(for: deadlineID)
    }

    func saveReminderOffsets(
        _ offsets: Set<TimeInterval>,
        for context: DeadlineReminderContext
    ) async -> ReminderSchedulingResult {
        do {
            let rules = makeRules(deadlineID: context.deadlineID, offsets: offsets)
            try await replaceRules(deadlineID: context.deadlineID, with: rules)
            return try await reconcile(context: context, rules: rules, requestsAuthorization: true)
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    func synchronizeReminders(for contexts: [DeadlineReminderContext]) async {
        await removeObsoleteReminders(currentDeadlineIDs: Set(contexts.map(\.deadlineID)))
        for context in contexts {
            do {
                let rules = try await reminderRepository.rules(for: context.deadlineID)
                _ = try await reconcile(context: context, rules: rules, requestsAuthorization: false)
            } catch {
                await scheduler.removeAll(for: context.deadlineID)
            }
        }
    }

    private func removeObsoleteReminders(currentDeadlineIDs: Set<String>) async {
        do {
            let allRules = try await reminderRepository.loadAll()
            let obsoleteDeadlineIDs = Set(allRules.map(\.deadlineID)).subtracting(currentDeadlineIDs)
            for deadlineID in obsoleteDeadlineIDs {
                await scheduler.removeAll(for: deadlineID)
                try await reminderRepository.deleteAll(for: deadlineID)
            }
        } catch {
            return
        }
    }

    private func reconcile(
        context: DeadlineReminderContext,
        rules: [ReminderRule],
        requestsAuthorization: Bool
    ) async throws -> ReminderSchedulingResult {
        await scheduler.removeAll(for: context.deadlineID)
        guard !rules.isEmpty else {
            return .savedWithoutScheduling
        }
        guard context.availability == .available, let deadlineDate = context.deadlineDate else {
            return .savedWithoutScheduling
        }
        let requests = notificationRequests(for: context, rules: rules, deadlineDate: deadlineDate)
        guard !requests.isEmpty else {
            return .savedWithoutScheduling
        }
        if requestsAuthorization {
            let isAuthorized = try await scheduler.requestAuthorization()
            guard isAuthorized else {
                return .authorizationDenied
            }
        }
        for request in requests {
            try await scheduler.schedule(request)
        }
        return .scheduled(count: requests.count)
    }

    private func notificationRequests(
        for context: DeadlineReminderContext,
        rules: [ReminderRule],
        deadlineDate: Date
    ) -> [DeadlineNotificationRequest] {
        rules.compactMap { rule in
            let deliveryDate = deadlineDate.addingTimeInterval(-rule.offsetSeconds)
            guard deliveryDate > clock.now else {
                return nil
            }
            return DeadlineNotificationRequest(
                identifier: rule.id,
                deadlineID: context.deadlineID,
                title: "\(context.conferenceTitle) \(context.deadlineTypeText) Deadline is in \(offsetText(rule.offsetSeconds))",
                body: "Deadline: \(Self.beijingNotificationTime(deadlineDate))",
                deliveryDate: deliveryDate
            )
        }
    }

    private func replaceRules(deadlineID: String, with rules: [ReminderRule]) async throws {
        try await reminderRepository.deleteAll(for: deadlineID)
        for rule in rules {
            try await reminderRepository.save(rule)
        }
    }

    private func makeRules(deadlineID: String, offsets: Set<TimeInterval>) -> [ReminderRule] {
        offsets
            .sorted()
            .map { offset in
                ReminderRule(
                    id: NotificationIdentifier.reminder(deadlineID: deadlineID, offsetSeconds: offset),
                    deadlineID: deadlineID,
                    offsetSeconds: offset
                )
            }
    }

    private func offsetText(_ offset: TimeInterval) -> String {
        if offset >= 24 * 60 * 60 {
            let days = Int(offset / (24 * 60 * 60))
            return days == 1 ? "1 day" : "\(days) days"
        }
        let hours = Int(offset / (60 * 60))
        return hours == 1 ? "1 hour" : "\(hours) hours"
    }

    private static func beijingNotificationTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return "\(formatter.string(from: date)) Beijing Time"
    }
}
