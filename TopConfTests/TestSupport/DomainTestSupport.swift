import Foundation
@testable import TopConf

struct FixedClock: Clock {
    let now: Date

    static let standard = FixedClock(now: Date(timeIntervalSince1970: 1_782_172_800))
}

enum DomainTestFactory {
    static let ai = ConferenceCategory(sourceID: "category-ai", displayName: "Artificial Intelligence")
    static let graphics = ConferenceCategory(sourceID: "category-graphics", displayName: "Computer Graphics and Multimedia")
    static let hci = ConferenceCategory(sourceID: "category-hci", displayName: "Human-Computer Interaction and Ubiquitous Computing")
    static let interdisciplinary = ConferenceCategory(sourceID: "category-interdisciplinary", displayName: "Interdisciplinary, Comprehensive, and Emerging Areas")
    static let unknown = ConferenceCategory(sourceID: "category-unknown", displayName: "Unknown")

    static var referenceDate: Date { FixedClock.standard.now }

    static func date(daysFromReference days: Int, hours: Int = 0, minutes: Int = 0) -> Date {
        referenceDate.addingTimeInterval(TimeInterval(days * 24 * 60 * 60 + hours * 60 * 60 + minutes * 60))
    }

    static func conference(
        id: String = "ai-neurips",
        abbreviation: String = "NeurIPS",
        fullName: String = "Conference on Neural Information Processing Systems",
        category: ConferenceCategory = ai,
        rank: CCFRank = .a,
        editions: [ConferenceEdition]? = nil
    ) -> Conference {
        Conference(
            id: id,
            abbreviation: abbreviation,
            fullName: fullName,
            category: category,
            ccfRank: rank,
            websiteURL: URL(string: "https://example.com/\(id)"),
            editions: editions ?? [edition(conferenceID: id)],
            lastUpdatedAt: nil
        )
    }

    static func edition(
        id: String? = nil,
        conferenceID: String = "ai-neurips",
        year: Int = 2026,
        deadlines: [Deadline]? = nil
    ) -> ConferenceEdition {
        ConferenceEdition(
            id: id ?? "\(conferenceID)-\(year)",
            conferenceID: conferenceID,
            year: year,
            conferenceStartDate: nil,
            conferenceEndDate: nil,
            location: nil,
            deadlines: deadlines ?? [deadline(editionID: id ?? "\(conferenceID)-\(year)")]
        )
    }

    static func deadline(
        id: String? = nil,
        editionID: String = "ai-neurips-2026",
        type: DeadlineType = .paper,
        date: Date? = date(daysFromReference: 10),
        rawDateValue: String? = "2026-07-03T00:00:00Z"
    ) -> Deadline {
        Deadline(
            id: id ?? "\(editionID)-\(type.rawValue)",
            editionID: editionID,
            type: type,
            date: date,
            originalTimeZoneIdentifier: "UTC",
            rawDateValue: rawDateValue,
            comment: nil
        )
    }

    static func tracked(_ conferenceID: String) -> TrackedConference {
        TrackedConference(conferenceID: conferenceID, addedAt: referenceDate)
    }
}
