import Foundation
@testable import TopConf

enum DeadlineFixtures {
    static func future(
        conferenceID: String,
        year: Int = 2026,
        type: DeadlineType = .paper,
        daysFromReference: Int,
        timezone: String = "UTC",
        rawDateValue: String? = nil
    ) -> Deadline {
        deadline(
            conferenceID: conferenceID,
            year: year,
            type: type,
            date: DomainTestFactory.date(daysFromReference: daysFromReference),
            timezone: timezone,
            rawDateValue: rawDateValue ?? "\(conferenceID)-\(year)-\(type.rawValue)-future"
        )
    }

    static func closed(
        conferenceID: String,
        year: Int = 2026,
        type: DeadlineType = .paper,
        daysFromReference: Int = -10,
        timezone: String = "UTC"
    ) -> Deadline {
        deadline(
            conferenceID: conferenceID,
            year: year,
            type: type,
            date: DomainTestFactory.date(daysFromReference: daysFromReference),
            timezone: timezone,
            rawDateValue: "\(conferenceID)-\(year)-\(type.rawValue)-closed"
        )
    }

    static func tbd(
        conferenceID: String,
        year: Int = 2027,
        type: DeadlineType = .paper
    ) -> Deadline {
        deadline(
            conferenceID: conferenceID,
            year: year,
            type: type,
            date: nil,
            timezone: nil,
            rawDateValue: "TBD"
        )
    }

    static func aoe(
        conferenceID: String,
        year: Int = 2026,
        type: DeadlineType = .paper,
        daysFromReference: Int = 90
    ) -> Deadline {
        future(
            conferenceID: conferenceID,
            year: year,
            type: type,
            daysFromReference: daysFromReference,
            timezone: "AoE",
            rawDateValue: "Sep 21, 2026 23:59 AoE"
        )
    }

    static func iana(
        conferenceID: String,
        year: Int = 2026,
        type: DeadlineType = .paper,
        daysFromReference: Int = 45
    ) -> Deadline {
        future(
            conferenceID: conferenceID,
            year: year,
            type: type,
            daysFromReference: daysFromReference,
            timezone: "America/Los_Angeles",
            rawDateValue: "Aug 7, 2026 23:59 America/Los_Angeles"
        )
    }

    private static func deadline(
        conferenceID: String,
        year: Int,
        type: DeadlineType,
        date: Date?,
        timezone: String?,
        rawDateValue: String?
    ) -> Deadline {
        let editionID = "\(conferenceID)-\(year)"
        return Deadline(
            id: "\(editionID)-\(type.rawValue)",
            editionID: editionID,
            type: type,
            date: date,
            originalTimeZoneIdentifier: timezone,
            rawDateValue: rawDateValue,
            comment: nil
        )
    }
}
