import Foundation
@testable import TopConf

enum ConferenceFixtures {
    static let ai = ConferenceCategory(sourceID: "category-ai", displayName: "Artificial Intelligence")
    static let graphics = ConferenceCategory(sourceID: "category-graphics", displayName: "Computer Graphics and Multimedia")
    static let hci = ConferenceCategory(sourceID: "category-hci", displayName: "Human-Computer Interaction and Ubiquitous Computing")
    static let interdisciplinary = ConferenceCategory(sourceID: "category-interdisciplinary", displayName: "Interdisciplinary, Comprehensive, and Emerging Areas")
    static let unknown = ConferenceCategory(sourceID: "upstream-new-area", displayName: "Newly Introduced Area")

    static func catalog() -> [Conference] {
        [
            multipleDeadlineConference(),
            upcomingAIConference(),
            tbdConference(),
            closedConference(),
            multipleEditionConference(),
            unknownCategoryConference(),
            simpleConference(id: "ai-aaai", abbreviation: "AAAI", fullName: "AAAI Conference on Artificial Intelligence", category: ai, rank: .a, daysFromReference: 30),
            simpleConference(id: "ai-ijcai", abbreviation: "IJCAI", fullName: "International Joint Conference on Artificial Intelligence", category: ai, rank: .a, daysFromReference: 50),
            simpleConference(id: "graphics-acm-mm", abbreviation: "ACM MM", fullName: "ACM Multimedia", category: graphics, rank: .a, daysFromReference: 60),
            simpleConference(id: "hci-uist", abbreviation: "UIST", fullName: "ACM Symposium on User Interface Software and Technology", category: hci, rank: .a, daysFromReference: 70),
            simpleConference(id: "interdisciplinary-rtss", abbreviation: "RTSS", fullName: "The IEEE Real-Time Systems Symposium", category: interdisciplinary, rank: .a, daysFromReference: 80)
        ]
    }

    static func upcomingAIConference() -> Conference {
        conference(
            id: "ai-neurips",
            abbreviation: "NeurIPS",
            fullName: "Conference on Neural Information Processing Systems",
            category: ai,
            rank: .a,
            deadlines: [DeadlineFixtures.aoe(conferenceID: "ai-neurips", daysFromReference: 90)]
        )
    }

    static func multipleDeadlineConference() -> Conference {
        conference(
            id: "hci-chi",
            abbreviation: "CHI",
            fullName: "ACM Conference on Human Factors in Computing Systems",
            category: hci,
            rank: .a,
            deadlines: [
                DeadlineFixtures.future(conferenceID: "hci-chi", type: .supplementary, daysFromReference: 35),
                DeadlineFixtures.future(conferenceID: "hci-chi", type: .paper, daysFromReference: 14, timezone: "America/New_York", rawDateValue: "Jul 7, 2026 23:59 America/New_York"),
                DeadlineFixtures.closed(conferenceID: "hci-chi", type: .abstract, daysFromReference: -2)
            ]
        )
    }

    static func tbdConference() -> Conference {
        conference(
            id: "graphics-siggraph",
            abbreviation: "SIGGRAPH",
            fullName: "ACM SIGGRAPH Conference",
            category: graphics,
            rank: .a,
            year: 2027,
            deadlines: [DeadlineFixtures.tbd(conferenceID: "graphics-siggraph", year: 2027)]
        )
    }

    static func closedConference() -> Conference {
        conference(
            id: "interdisciplinary-www",
            abbreviation: "WWW",
            fullName: "The Web Conference",
            category: interdisciplinary,
            rank: .a,
            deadlines: [
                DeadlineFixtures.closed(conferenceID: "interdisciplinary-www", type: .abstract, daysFromReference: -25),
                DeadlineFixtures.closed(conferenceID: "interdisciplinary-www", type: .paper, daysFromReference: -20)
            ]
        )
    }

    static func multipleEditionConference() -> Conference {
        let closed2026 = edition(
            conferenceID: "ai-iclr",
            year: 2026,
            deadlines: [DeadlineFixtures.closed(conferenceID: "ai-iclr", year: 2026, daysFromReference: -30)]
        )
        let future2027 = edition(
            conferenceID: "ai-iclr",
            year: 2027,
            deadlines: [DeadlineFixtures.iana(conferenceID: "ai-iclr", year: 2027, daysFromReference: 120)]
        )
        return conference(
            id: "ai-iclr",
            abbreviation: "ICLR",
            fullName: "International Conference on Learning Representations",
            category: ai,
            rank: .a,
            editions: [closed2026, future2027]
        )
    }

    static func unknownCategoryConference() -> Conference {
        simpleConference(
            id: "unknown-qis",
            abbreviation: "QIS",
            fullName: "Quantum Information Systems Conference",
            category: unknown,
            rank: .unknown,
            daysFromReference: 110
        )
    }

    static func renamedNeurIPS() -> Conference {
        conference(
            id: "ai-neurips",
            abbreviation: "NIPS",
            fullName: "Renamed Neural Information Processing Conference",
            category: ai,
            rank: .a,
            deadlines: [DeadlineFixtures.aoe(conferenceID: "ai-neurips", daysFromReference: 90)]
        )
    }

    static func rankChangedNeurIPS() -> Conference {
        conference(
            id: "ai-neurips",
            abbreviation: "NeurIPS",
            fullName: "Conference on Neural Information Processing Systems",
            category: ai,
            rank: .b,
            deadlines: [DeadlineFixtures.aoe(conferenceID: "ai-neurips", daysFromReference: 90)]
        )
    }

    static func categoryChangedNeurIPS() -> Conference {
        conference(
            id: "ai-neurips",
            abbreviation: "NeurIPS",
            fullName: "Conference on Neural Information Processing Systems",
            category: interdisciplinary,
            rank: .a,
            deadlines: [DeadlineFixtures.aoe(conferenceID: "ai-neurips", daysFromReference: 90)]
        )
    }

    static func lastKnownFallbackConference() -> Conference {
        upcomingAIConference()
    }

    private static func simpleConference(
        id: String,
        abbreviation: String,
        fullName: String,
        category: ConferenceCategory,
        rank: CCFRank,
        daysFromReference: Int
    ) -> Conference {
        conference(
            id: id,
            abbreviation: abbreviation,
            fullName: fullName,
            category: category,
            rank: rank,
            deadlines: [DeadlineFixtures.future(conferenceID: id, daysFromReference: daysFromReference)]
        )
    }

    private static func conference(
        id: String,
        abbreviation: String,
        fullName: String,
        category: ConferenceCategory,
        rank: CCFRank,
        year: Int = 2026,
        deadlines: [Deadline]
    ) -> Conference {
        conference(
            id: id,
            abbreviation: abbreviation,
            fullName: fullName,
            category: category,
            rank: rank,
            editions: [edition(conferenceID: id, year: year, deadlines: deadlines)]
        )
    }

    private static func conference(
        id: String,
        abbreviation: String,
        fullName: String,
        category: ConferenceCategory,
        rank: CCFRank,
        editions: [ConferenceEdition]
    ) -> Conference {
        Conference(
            id: id,
            abbreviation: abbreviation,
            fullName: fullName,
            category: category,
            ccfRank: rank,
            websiteURL: URL(string: "https://example.com/\(id)"),
            editions: editions,
            lastUpdatedAt: DomainTestFactory.referenceDate
        )
    }

    private static func edition(
        conferenceID: String,
        year: Int,
        deadlines: [Deadline]
    ) -> ConferenceEdition {
        ConferenceEdition(
            id: "\(conferenceID)-\(year)",
            conferenceID: conferenceID,
            year: year,
            conferenceStartDate: nil,
            conferenceEndDate: nil,
            location: nil,
            deadlines: deadlines
        )
    }
}
