import Foundation
import SwiftData

@Model
final class TrackedConferenceEntity {
    @Attribute(.unique) var conferenceID: String
    var addedAt: Date

    init(conferenceID: String, addedAt: Date) {
        self.conferenceID = conferenceID
        self.addedAt = addedAt
    }
}
