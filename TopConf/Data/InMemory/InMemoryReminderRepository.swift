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

    func rules(for deadlineID: String) async throws -> [ReminderRule] {
        rulesByID.values
            .filter { $0.deadlineID == deadlineID }
            .sorted { lhs, rhs in
                if lhs.offsetSeconds != rhs.offsetSeconds {
                    return lhs.offsetSeconds < rhs.offsetSeconds
                }
                return lhs.id < rhs.id
            }
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
}
