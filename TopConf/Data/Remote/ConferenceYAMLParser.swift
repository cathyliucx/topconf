import Foundation
import Yams

struct ConferenceYAMLParser {
    private let categoryMapper: ConferenceCategoryMapper
    private let timeZoneParser: DeadlineTimeZoneParser

    init(
        categoryMapper: ConferenceCategoryMapper = ConferenceCategoryMapper(),
        timeZoneParser: DeadlineTimeZoneParser = DeadlineTimeZoneParser()
    ) {
        self.categoryMapper = categoryMapper
        self.timeZoneParser = timeZoneParser
    }

    func parse(_ yaml: String, capturedAt: Date? = nil, stableID: String? = nil) throws -> Conference {
        guard let root = try Yams.load(yaml: yaml) as? [String: Any] else {
            throw RemoteCatalogError.malformedRoot
        }
        return try parse(root, capturedAt: capturedAt, stableID: stableID)
    }

    private func parse(_ root: [String: Any], capturedAt: Date?, stableID: String?) throws -> Conference {
        guard let abbreviation = nonEmptyString(root["title"]) else {
            throw RemoteCatalogError.malformedRoot
        }
        let category = categoryMapper.category(for: string(root["sub"]))
        let conferenceID = stableID ?? "\(category.sourceID.lowercased())-\(Self.slug(abbreviation))"
        let editions = ((root["confs"] as? [[String: Any]]) ?? []).compactMap { editionRoot in
            parseEdition(editionRoot, conferenceID: conferenceID)
        }
        guard !editions.isEmpty else {
            throw RemoteCatalogError.malformedRoot
        }
        let websiteURL = (root["confs"] as? [[String: Any]])?
            .sorted { (int($0["year"]) ?? 0) > (int($1["year"]) ?? 0) }
            .compactMap { validURL(from: string($0["link"])) }
            .first

        return Conference(
            id: conferenceID,
            abbreviation: abbreviation,
            fullName: nonEmptyString(root["description"]) ?? abbreviation,
            category: category,
            ccfRank: Self.rank(from: (root["rank"] as? [String: Any])?["ccf"]),
            websiteURL: websiteURL,
            editions: editions,
            lastUpdatedAt: capturedAt
        )
    }

    private func parseEdition(_ root: [String: Any], conferenceID: String) -> ConferenceEdition? {
        guard let year = int(root["year"]) else {
            return nil
        }
        let editionID = nonEmptyString(root["id"]) ?? "\(conferenceID)-\(year)"
        let timezone = timeZoneParser.timeZone(for: string(root["timezone"]))
        let timelines = (root["timeline"] as? [[String: Any]]) ?? []
        let deadlines = timelines.enumerated().flatMap { index, timeline in
            parseDeadlines(timeline, editionID: editionID, timeZone: timezone, index: index)
        }

        return ConferenceEdition(
            id: editionID,
            conferenceID: conferenceID,
            year: year,
            conferenceStartDate: nil,
            conferenceEndDate: nil,
            location: string(root["place"]),
            deadlines: deadlines.sorted(by: Self.sortDeadlines)
        )
    }

    private func parseDeadlines(
        _ timeline: [String: Any],
        editionID: String,
        timeZone: TimeZone,
        index: Int
    ) -> [Deadline] {
        timeline.compactMap { key, value in
            guard let type = Self.deadlineType(for: key),
                  let rawValue = string(value) else {
                return nil
            }
            let suffix = index == 0 ? type.rawValue : "\(type.rawValue)-\(index + 1)"
            return Deadline(
                id: "\(editionID)-\(suffix)",
                editionID: editionID,
                type: type,
                date: timeZoneParser.date(from: rawValue, timeZone: timeZone),
                originalTimeZoneIdentifier: timeZone.identifier,
                rawDateValue: rawValue,
                comment: string(timeline["comment"])
            )
        }
    }

    private func nonEmptyString(_ value: Any?) -> String? {
        let result = string(value)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return result?.isEmpty == false ? result : nil
    }

    private func string(_ value: Any?) -> String? {
        value as? String
    }

    private func int(_ value: Any?) -> Int? {
        if let int = value as? Int {
            return int
        }
        if let string = value as? String {
            return Int(string)
        }
        return nil
    }

    private func validURL(from value: String?) -> URL? {
        guard let value,
              let url = URL(string: value),
              url.scheme != nil,
              url.host != nil else {
            return nil
        }
        return url
    }

    private static func rank(from value: Any?) -> CCFRank {
        switch (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() {
        case "A":
            return .a
        case "B":
            return .b
        case "C":
            return .c
        case nil, "":
            return .unknown
        default:
            return .unknown
        }
    }

    private static func deadlineType(for key: String) -> DeadlineType? {
        switch key {
        case "abstract_deadline":
            return .abstract
        case "deadline":
            return .paper
        case "supplementary_deadline":
            return .supplementary
        case "rebuttal_deadline":
            return .rebuttal
        case "camera_ready_deadline":
            return .cameraReady
        case "registration_deadline":
            return .registration
        default:
            return key.hasSuffix("_deadline") ? .other : nil
        }
    }

    private static func sortDeadlines(_ lhs: Deadline, _ rhs: Deadline) -> Bool {
        deadlineSortIndex(lhs.type) < deadlineSortIndex(rhs.type)
    }

    private static func deadlineSortIndex(_ type: DeadlineType) -> Int {
        switch type {
        case .abstract:
            return 0
        case .paper:
            return 1
        case .supplementary:
            return 2
        case .rebuttal:
            return 3
        case .cameraReady:
            return 4
        case .registration:
            return 5
        case .other:
            return 6
        }
    }

    private static func slug(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics
        let scalars = value.lowercased().unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        return String(scalars)
            .split(separator: "-")
            .joined(separator: "-")
    }
}

struct DeadlineTimeZoneParser {
    func timeZone(for identifier: String?) -> TimeZone {
        let rawValue = identifier?.trimmingCharacters(in: .whitespacesAndNewlines)
        switch rawValue?.uppercased() {
        case "AOE", "UTC-12":
            return TimeZone(secondsFromGMT: -12 * 60 * 60) ?? TimeZone(identifier: "UTC") ?? .current
        case "UTC", "GMT":
            return TimeZone(secondsFromGMT: 0) ?? TimeZone(identifier: "UTC") ?? .current
        default:
            return rawValue.flatMap(TimeZone.init(identifier:)) ?? TimeZone(secondsFromGMT: 0) ?? TimeZone(identifier: "UTC") ?? .current
        }
    }

    func date(from rawValue: String, timeZone: TimeZone) -> Date? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.uppercased() != "TBD" else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.date(from: trimmed)
    }
}
