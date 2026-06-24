import Foundation
import SwiftData

@Model
final class ReminderEntity {
    @Attribute(.unique) var id: String
    var deadlineID: String
    var offsetSeconds: TimeInterval
    var isEnabled: Bool

    init(id: String, deadlineID: String, offsetSeconds: TimeInterval, isEnabled: Bool = true) {
        self.id = id
        self.deadlineID = deadlineID
        self.offsetSeconds = offsetSeconds
        self.isEnabled = isEnabled
    }
}
