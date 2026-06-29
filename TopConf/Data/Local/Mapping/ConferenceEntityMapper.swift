import Foundation

enum ConferenceEntityMapper {
    static func makeEntity(from conference: Conference) -> ConferenceEntity {
        ConferenceEntity(
            id: conference.id,
            abbreviation: conference.abbreviation,
            fullName: conference.fullName,
            categorySourceID: conference.category.sourceID,
            categoryDisplayName: conference.category.displayName,
            ccfRankRawValue: conference.ccfRank.rawValue,
            websiteURLString: conference.websiteURL?.absoluteString,
            lastUpdatedAt: conference.lastUpdatedAt,
            editions: conference.editions.map(makeEntity(from:))
        )
    }

    static func makeDomain(from entity: ConferenceEntity) -> Conference {
        Conference(
            id: entity.id,
            abbreviation: entity.abbreviation,
            fullName: entity.fullName,
            category: ConferenceCategory(
                sourceID: entity.categorySourceID,
                displayName: entity.categoryDisplayName
            ),
            ccfRank: CCFRank(rawValue: entity.ccfRankRawValue) ?? .unknown,
            websiteURL: entity.websiteURLString.flatMap(URL.init(string:)),
            editions: entity.editions
                .map(makeDomain(from:))
                .sorted { lhs, rhs in lhs.id < rhs.id },
            lastUpdatedAt: entity.lastUpdatedAt
        )
    }

    private static func makeEntity(from edition: ConferenceEdition) -> ConferenceEditionEntity {
        ConferenceEditionEntity(
            id: edition.id,
            conferenceID: edition.conferenceID,
            year: edition.year,
            conferenceStartDate: edition.conferenceStartDate,
            conferenceEndDate: edition.conferenceEndDate,
            location: edition.location,
            deadlines: edition.deadlines.map(makeEntity(from:))
        )
    }

    private static func makeDomain(from entity: ConferenceEditionEntity) -> ConferenceEdition {
        ConferenceEdition(
            id: entity.id,
            conferenceID: entity.conferenceID,
            year: entity.year,
            conferenceStartDate: entity.conferenceStartDate,
            conferenceEndDate: entity.conferenceEndDate,
            location: entity.location,
            deadlines: entity.deadlines
                .map(makeDomain(from:))
                .sorted { lhs, rhs in lhs.id < rhs.id }
        )
    }

    private static func makeEntity(from deadline: Deadline) -> DeadlineEntity {
        DeadlineEntity(
            id: deadline.id,
            editionID: deadline.editionID,
            typeRawValue: deadline.type.rawValue,
            date: deadline.date,
            originalTimeZoneIdentifier: deadline.originalTimeZoneIdentifier,
            rawDateValue: deadline.rawDateValue,
            comment: deadline.comment
        )
    }

    private static func makeDomain(from entity: DeadlineEntity) -> Deadline {
        Deadline(
            id: entity.id,
            editionID: entity.editionID,
            type: DeadlineType(rawValue: entity.typeRawValue) ?? .other,
            date: entity.date,
            originalTimeZoneIdentifier: entity.originalTimeZoneIdentifier,
            rawDateValue: entity.rawDateValue,
            comment: entity.comment
        )
    }
}
