import Foundation

enum ReminderEntityMapper {
    static func makeEntity(from rule: ReminderRule) -> ReminderEntity {
        ReminderEntity(
            id: rule.id,
            deadlineID: rule.deadlineID,
            offsetSeconds: rule.offsetSeconds
        )
    }

    static func update(_ entity: ReminderEntity, from rule: ReminderRule) {
        entity.deadlineID = rule.deadlineID
        entity.offsetSeconds = rule.offsetSeconds
        entity.isEnabled = true
    }

    static func makeDomain(from entity: ReminderEntity) -> ReminderRule {
        ReminderRule(
            id: entity.id,
            deadlineID: entity.deadlineID,
            offsetSeconds: entity.offsetSeconds
        )
    }
}
