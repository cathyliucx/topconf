import Foundation
import SwiftData

actor SwiftDataReminderRepository: ReminderRepository {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func rules(for deadlineID: String) async throws -> [ReminderRule] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ReminderEntity>(
            predicate: #Predicate { $0.deadlineID == deadlineID },
            sortBy: [
                SortDescriptor(\ReminderEntity.offsetSeconds),
                SortDescriptor(\ReminderEntity.id)
            ]
        )
        return try context.fetch(descriptor).map(ReminderEntityMapper.makeDomain(from:))
    }

    func save(_ rule: ReminderRule) async throws {
        let context = ModelContext(container)
        if let existing = try entity(ruleID: rule.id, in: context) {
            ReminderEntityMapper.update(existing, from: rule)
        } else {
            context.insert(ReminderEntityMapper.makeEntity(from: rule))
        }
        try context.save()
    }

    func delete(ruleID: String) async throws {
        let context = ModelContext(container)
        if let existing = try entity(ruleID: ruleID, in: context) {
            context.delete(existing)
            try context.save()
        }
    }

    func deleteAll(for deadlineID: String) async throws {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ReminderEntity>(
            predicate: #Predicate { $0.deadlineID == deadlineID }
        )
        for entity in try context.fetch(descriptor) {
            context.delete(entity)
        }
        try context.save()
    }

    private func entity(ruleID: String, in context: ModelContext) throws -> ReminderEntity? {
        var descriptor = FetchDescriptor<ReminderEntity>(
            predicate: #Predicate { $0.id == ruleID }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
