import Foundation
import SwiftData

@Model
final class DeadlineEntity {
    @Attribute(.unique) var id: String
    var editionID: String
    var typeRawValue: String
    var date: Date?
    var originalTimeZoneIdentifier: String?
    var rawDateValue: String?
    var comment: String?
    var edition: ConferenceEditionEntity?

    init(
        id: String,
        editionID: String,
        typeRawValue: String,
        date: Date?,
        originalTimeZoneIdentifier: String?,
        rawDateValue: String?,
        comment: String?
    ) {
        self.id = id
        self.editionID = editionID
        self.typeRawValue = typeRawValue
        self.date = date
        self.originalTimeZoneIdentifier = originalTimeZoneIdentifier
        self.rawDateValue = rawDateValue
        self.comment = comment
        self.edition = nil
    }
}
