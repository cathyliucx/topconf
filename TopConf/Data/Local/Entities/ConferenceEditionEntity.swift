import Foundation
import SwiftData

@Model
final class ConferenceEditionEntity {
    @Attribute(.unique) var id: String
    var conferenceID: String
    var year: Int
    var conferenceStartDate: Date?
    var conferenceEndDate: Date?
    var location: String?
    @Relationship(deleteRule: .cascade, inverse: \DeadlineEntity.edition) var deadlines: [DeadlineEntity]
    var conference: ConferenceEntity?

    init(
        id: String,
        conferenceID: String,
        year: Int,
        conferenceStartDate: Date?,
        conferenceEndDate: Date?,
        location: String?,
        deadlines: [DeadlineEntity]
    ) {
        self.id = id
        self.conferenceID = conferenceID
        self.year = year
        self.conferenceStartDate = conferenceStartDate
        self.conferenceEndDate = conferenceEndDate
        self.location = location
        self.deadlines = deadlines
        self.conference = nil
    }
}
