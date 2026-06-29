import Foundation
import SwiftData

@Model
final class ConferenceEntity {
    @Attribute(.unique) var id: String
    var abbreviation: String
    var fullName: String
    var categorySourceID: String
    var categoryDisplayName: String
    var ccfRankRawValue: String
    var websiteURLString: String?
    var lastUpdatedAt: Date?
    @Relationship(deleteRule: .cascade, inverse: \ConferenceEditionEntity.conference) var editions: [ConferenceEditionEntity]

    init(
        id: String,
        abbreviation: String,
        fullName: String,
        categorySourceID: String,
        categoryDisplayName: String,
        ccfRankRawValue: String,
        websiteURLString: String?,
        lastUpdatedAt: Date?,
        editions: [ConferenceEditionEntity]
    ) {
        self.id = id
        self.abbreviation = abbreviation
        self.fullName = fullName
        self.categorySourceID = categorySourceID
        self.categoryDisplayName = categoryDisplayName
        self.ccfRankRawValue = ccfRankRawValue
        self.websiteURLString = websiteURLString
        self.lastUpdatedAt = lastUpdatedAt
        self.editions = editions
    }
}
