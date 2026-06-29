import Foundation

enum SeedConferenceCatalog {
    static let ai = ConferenceCategory(sourceID: "category-ai", displayName: "Artificial Intelligence")
    static let graphics = ConferenceCategory(sourceID: "category-graphics", displayName: "Computer Graphics and Multimedia")
    static let hci = ConferenceCategory(sourceID: "category-hci", displayName: "Human-Computer Interaction and Ubiquitous Computing")
    static let interdisciplinary = ConferenceCategory(sourceID: "category-interdisciplinary", displayName: "Interdisciplinary, Comprehensive, and Emerging Areas")

    static let supportedCategoryIDs: Set<String> = [
        ai.sourceID,
        graphics.sourceID,
        hci.sourceID,
        interdisciplinary.sourceID
    ]

    static let seededAt = Date(timeIntervalSince1970: 1_750_636_800)

    // Temporary Phase 4/5 development catalog. This is intentionally larger than
    // the tracking limit so discovery/search can prove they are not capped, and
    // includes deadline states used by the Phase 5 tracked-list UI.
    // It is not a complete CCFDDL catalog and will be replaced by structured
    // catalog ingestion in a later SOP phase.
    static func conferences() -> [Conference] {
        [
            conference(id: "ai-aaai", abbreviation: "AAAI", fullName: "AAAI Conference on Artificial Intelligence", category: ai, rank: .a, year: 2027),
            conference(id: "ai-aamas", abbreviation: "AAMAS", fullName: "International Conference on Autonomous Agents and Multiagent Systems", category: ai, rank: .b, year: 2027),
            conference(id: "ai-acl", abbreviation: "ACL", fullName: "Annual Meeting of the Association for Computational Linguistics Conference", category: ai, rank: .a, year: 2027),
            conference(id: "ai-colt", abbreviation: "COLT", fullName: "Conference on Learning Theory", category: ai, rank: .b, year: 2027),
            conference(id: "ai-cvpr", abbreviation: "CVPR", fullName: "Conference on Computer Vision and Pattern Recognition", category: ai, rank: .a, year: 2027),
            conference(id: "ai-emnlp", abbreviation: "EMNLP", fullName: "Conference on Empirical Methods in Natural Language Processing", category: ai, rank: .b, year: 2027),
            conference(id: "ai-ijcai", abbreviation: "IJCAI", fullName: "International Joint Conference on Artificial Intelligence", category: ai, rank: .a, year: 2027),
            conference(id: "ai-iclr", abbreviation: "ICLR", fullName: "International Conference on Learning Representations", category: ai, rank: .a, year: 2027),
            conference(id: "ai-icml", abbreviation: "ICML", fullName: "International Conference on Machine Learning", category: ai, rank: .a, year: 2027),
            conference(id: "ai-kr", abbreviation: "KR", fullName: "International Conference on Principles of Knowledge Representation and Reasoning", category: ai, rank: .b, year: 2027),
            conference(id: "ai-mlsys", abbreviation: "MLSys", fullName: "Conference on Machine Learning and Systems", category: ai, rank: .unranked, year: 2027),
            conference(id: "ai-neurips", abbreviation: "NeurIPS", fullName: "Conference on Neural Information Processing Systems", category: ai, rank: .a, year: 2027),
            conference(id: "ai-uai", abbreviation: "UAI", fullName: "Conference on Uncertainty in Artificial Intelligence", category: ai, rank: .b, year: 2027),
            conference(id: "graphics-acm-mm", abbreviation: "ACM MM", fullName: "ACM Multimedia Conference", category: graphics, rank: .a, year: 2027),
            conference(id: "graphics-eurographics", abbreviation: "Eurographics", fullName: "Annual Conference of the European Association for Computer Graphics", category: graphics, rank: .b, year: 2027),
            conference(id: "graphics-gi", abbreviation: "GI", fullName: "Graphics Interface Conference", category: graphics, rank: .c, year: 2027),
            conference(id: "graphics-i3d", abbreviation: "I3D", fullName: "ACM SIGGRAPH Symposium on Interactive 3D Graphics and Games Conference", category: graphics, rank: .b, year: 2027),
            conference(id: "graphics-pacific", abbreviation: "Pacific Graphics", fullName: "Pacific Conference on Computer Graphics and Applications", category: graphics, rank: .b, year: 2027),
            conference(id: "graphics-sca", abbreviation: "SCA", fullName: "ACM SIGGRAPH Conference on Motion, Interaction and Games", category: graphics, rank: .c, year: 2027),
            conference(id: "graphics-siggraph", abbreviation: "SIGGRAPH", fullName: "ACM SIGGRAPH Conference", category: graphics, rank: .a, year: 2027),
            conference(id: "graphics-smi", abbreviation: "SMI", fullName: "Shape Modeling International Conference", category: graphics, rank: .c, year: 2027),
            conference(id: "hci-chi", abbreviation: "CHI", fullName: "ACM Conference on Human Factors in Computing Systems", category: hci, rank: .a, year: 2027),
            conference(id: "hci-dis", abbreviation: "DIS", fullName: "ACM Designing Interactive Systems Conference", category: hci, rank: .b, year: 2027),
            conference(id: "hci-iss", abbreviation: "ISS", fullName: "ACM Interactive Surfaces and Spaces Conference", category: hci, rank: .b, year: 2027),
            conference(id: "hci-iui", abbreviation: "IUI", fullName: "ACM Conference on Intelligent User Interfaces", category: hci, rank: .b, year: 2027),
            conference(id: "hci-mobilehci", abbreviation: "MobileHCI", fullName: "International Conference on Mobile Human-Computer Interaction", category: hci, rank: .c, year: 2027),
            conference(id: "hci-cscw", abbreviation: "CSCW", fullName: "ACM Conference on Computer-Supported Cooperative Work", category: hci, rank: .c, year: 2027),
            conference(id: "hci-uist", abbreviation: "UIST", fullName: "ACM Symposium on User Interface Software and Technology", category: hci, rank: .a, year: 2027),
            conference(id: "hci-ubicomp", abbreviation: "UbiComp", fullName: "ACM International Joint Conference on Pervasive and Ubiquitous Computing", category: hci, rank: .a, year: 2027),
            conference(id: "interdisciplinary-cikm", abbreviation: "CIKM", fullName: "ACM International Conference on Information and Knowledge Management", category: interdisciplinary, rank: .b, year: 2027),
            conference(id: "interdisciplinary-icwsm", abbreviation: "ICWSM", fullName: "International AAAI Conference on Web and Social Media", category: interdisciplinary, rank: .b, year: 2027),
            conference(id: "interdisciplinary-jcdl", abbreviation: "JCDL", fullName: "ACM/IEEE Joint Conference on Digital Libraries", category: interdisciplinary, rank: .c, year: 2027),
            conference(id: "interdisciplinary-www", abbreviation: "WWW", fullName: "The Web Conference", category: interdisciplinary, rank: .a, year: 2027),
            conference(id: "interdisciplinary-recsys", abbreviation: "RecSys", fullName: "ACM Conference on Recommender Systems", category: interdisciplinary, rank: .b, year: 2027),
            conference(id: "interdisciplinary-sigir", abbreviation: "SIGIR", fullName: "International ACM SIGIR Conference on Research and Development in Information Retrieval", category: interdisciplinary, rank: .a, year: 2027),
            conference(id: "interdisciplinary-wsdm", abbreviation: "WSDM", fullName: "ACM International Conference on Web Search and Data Mining", category: interdisciplinary, rank: .b, year: 2027)
        ]
    }

    private static func conference(
        id: String,
        abbreviation: String,
        fullName: String,
        category: ConferenceCategory,
        rank: CCFRank,
        year: Int
    ) -> Conference {
        Conference(
            id: id,
            abbreviation: abbreviation,
            fullName: fullName,
            category: category,
            ccfRank: rank,
            websiteURL: id == "hci-cscw" ? nil : URL(string: "https://example.com/\(id)"),
            editions: editions(for: id, year: year),
            lastUpdatedAt: seededAt
        )
    }

    private static func editions(for id: String, year: Int) -> [ConferenceEdition] {
        if id == "ai-ijcai" {
            return [
                edition(conferenceID: id, year: 2026, deadlines: [
                    deadline(conferenceID: id, year: 2026, type: .paper, days: -20, raw: "Jun 3, 23:59 AoE", zone: "AoE")
                ]),
                edition(conferenceID: id, year: year, deadlines: [
                    deadline(conferenceID: id, year: year, type: .paper, days: 20, raw: "Jul 13, 23:59 AoE", zone: "AoE")
                ])
            ]
        }

        return [
            edition(conferenceID: id, year: year, deadlines: deadlines(for: id, year: year))
        ]
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

    private static func deadlines(for id: String, year: Int) -> [Deadline] {
        switch id {
        case "interdisciplinary-www":
            return [deadline(conferenceID: id, year: year, type: .paper, minutes: 45, raw: "Jun 23, 00:45 UTC", zone: "UTC")]
        case "interdisciplinary-sigir":
            return [deadline(conferenceID: id, year: year, type: .paper, hours: 18, raw: "Jun 23, 18:00 UTC", zone: "UTC")]
        case "hci-chi":
            return [deadline(conferenceID: id, year: year, type: .paper, days: 3, raw: "Jun 25, 17:00 America/Los_Angeles", zone: "America/Los_Angeles")]
        case "ai-aaai", "ai-aamas":
            return [deadline(conferenceID: id, year: year, type: .paper, days: 5, raw: "Jun 28, 00:00 UTC", zone: "UTC")]
        case "ai-iclr":
            return [
                deadline(conferenceID: id, year: year, type: .abstract, days: -2, raw: "Jun 21, 23:59 AoE", zone: "AoE"),
                deadline(conferenceID: id, year: year, type: .paper, days: 10, raw: "Jul 3, 23:59 AoE", zone: "AoE")
            ]
        case "ai-neurips":
            return [deadline(conferenceID: id, year: year, type: .paper, days: 18, raw: "Jul 11, 23:59 AoE", zone: "AoE")]
        case "graphics-acm-mm":
            return [deadline(conferenceID: id, year: year, type: .paper, days: -1, raw: "Jun 22, 23:59 AoE", zone: "AoE")]
        case "graphics-siggraph":
            return [deadline(conferenceID: id, year: year, type: .paper, date: nil, raw: nil, zone: nil)]
        default:
            return [deadline(conferenceID: id, year: year, type: .paper, days: 100, raw: "Oct 1, 00:00 UTC", zone: "UTC")]
        }
    }

    private static func deadline(
        conferenceID: String,
        year: Int,
        type: DeadlineType,
        days: Int = 0,
        hours: Int = 0,
        minutes: Int = 0,
        raw: String?,
        zone: String?
    ) -> Deadline {
        deadline(
            conferenceID: conferenceID,
            year: year,
            type: type,
            date: seededAt.addingTimeInterval(TimeInterval(days * 24 * 60 * 60 + hours * 60 * 60 + minutes * 60)),
            raw: raw,
            zone: zone
        )
    }

    private static func deadline(
        conferenceID: String,
        year: Int,
        type: DeadlineType,
        date: Date?,
        raw: String?,
        zone: String?
    ) -> Deadline {
        Deadline(
            id: "\(conferenceID)-\(year)-\(type.rawValue)",
            editionID: "\(conferenceID)-\(year)",
            type: type,
            date: date,
            originalTimeZoneIdentifier: zone,
            rawDateValue: raw,
            comment: nil
        )
    }
}
