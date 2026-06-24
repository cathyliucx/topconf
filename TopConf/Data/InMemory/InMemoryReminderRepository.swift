import Foundation

actor InMemoryReminderRepository: ReminderRepository {
    private var rulesByID: [String: ReminderRule]

    init(rules: [ReminderRule] = []) {
        var result: [String: ReminderRule] = [:]
        for rule in rules {
            result[rule.id] = rule
        }
        self.rulesByID = result
    }

    func loadAll() async throws -> [ReminderRule] {
        sorted(Array(rulesByID.values))
    }

    func rules(for deadlineID: String) async throws -> [ReminderRule] {
        sorted(rulesByID.values.filter { $0.deadlineID == deadlineID })
    }

    func save(_ rule: ReminderRule) async throws {
        rulesByID[rule.id] = rule
    }

    func delete(ruleID: String) async throws {
        rulesByID.removeValue(forKey: ruleID)
    }

    func deleteAll(for deadlineID: String) async throws {
        rulesByID = rulesByID.filter { _, rule in
            rule.deadlineID != deadlineID
        }
    }

    private func sorted(_ rules: [ReminderRule]) -> [ReminderRule] {
        rules.sorted { lhs, rhs in
            if lhs.deadlineID != rhs.deadlineID {
                return lhs.deadlineID < rhs.deadlineID
            }
            if lhs.offsetSeconds != rhs.offsetSeconds {
                return lhs.offsetSeconds < rhs.offsetSeconds
            }
            return lhs.id < rhs.id
        }
    }
}
