import Foundation
import Yams

struct ConferenceYAMLParser {
    struct ParsedRecord: Equatable {
        let conference: Conference?
        let mappingResult: CategoryMappingResult
        let title: String
    }

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
        guard let conference = try parseRecords(yaml, capturedAt: capturedAt, stableID: stableID)
            .compactMap(\.conference)
            .first else {
            throw RemoteCatalogError.malformedRoot
        }
        return conference
    }

    func parseRecords(_ yaml: String, capturedAt: Date? = nil, stableID: String? = nil) throws -> [ParsedRecord] {
        let loaded = try Yams.load(yaml: yaml)
        let roots: [[String: Any]]
        if let root = loaded as? [String: Any] {
            roots = [root]
        } else if let array = loaded as? [[String: Any]] {
            roots = array
        } else {
            throw RemoteCatalogError.malformedRoot
        }

        let records = try roots.enumerated().map { index, root in
            try parseRecord(
                root,
                capturedAt: capturedAt,
                stableID: Self.stableID(for: stableID, root: root, index: index, count: roots.count)
            )
        }
        guard !records.isEmpty else {
            throw RemoteCatalogError.malformedRoot
        }
        return records
    }

    private func parseRecord(_ root: [String: Any], capturedAt: Date?, stableID: String?) throws -> ParsedRecord {
        guard let abbreviation = nonEmptyString(root["title"]) else {
            throw RemoteCatalogError.malformedRoot
        }
        let mappingResult = categoryMapper.mappingResult(for: string(root["sub"]))
        guard case let .supported(category) = mappingResult else {
            return ParsedRecord(conference: nil, mappingResult: mappingResult, title: abbreviation)
        }
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

        let conference = Conference(
            id: conferenceID,
            abbreviation: abbreviation,
            fullName: nonEmptyString(root["description"]) ?? abbreviation,
            category: category,
            ccfRank: Self.rank(from: (root["rank"] as? [String: Any])?["ccf"]),
            websiteURL: websiteURL,
            editions: editions,
            lastUpdatedAt: capturedAt
        )
        return ParsedRecord(conference: conference, mappingResult: mappingResult, title: abbreviation)
    }

    private func parseEdition(_ root: [String: Any], conferenceID: String) -> ConferenceEdition? {
        guard let year = int(root["year"]) else {
            return nil
        }
        let editionID = nonEmptyString(root["id"]) ?? "\(conferenceID)-\(year)"
        let rawTimeZone = nonEmptyString(root["timezone"])
        let timezone = timeZoneParser.timeZone(for: rawTimeZone)
        let timelines = (root["timeline"] as? [[String: Any]]) ?? []
        let deadlines = timelines.enumerated().flatMap { index, timeline in
            parseDeadlines(
                timeline,
                editionID: editionID,
                timeZone: timezone,
                originalTimeZoneIdentifier: rawTimeZone ?? timezone.identifier,
                index: index
            )
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
        originalTimeZoneIdentifier: String,
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
                originalTimeZoneIdentifier: originalTimeZoneIdentifier,
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

    private static func stableID(for stableID: String?, root: [String: Any], index: Int, count: Int) -> String? {
        guard let stableID else {
            return nil
        }
        guard count > 1 else {
            return stableID
        }
        let title = (root["title"] as? String) ?? "\(index + 1)"
        return "\(stableID)-\(slug(title))"
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
            if let offset = utcOffsetSeconds(from: rawValue) {
                return TimeZone(secondsFromGMT: offset) ?? TimeZone(identifier: "UTC") ?? .current
            }
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

    private func utcOffsetSeconds(from rawValue: String?) -> Int? {
        guard let rawValue else {
            return nil
        }
        let uppercased = rawValue.uppercased()
        guard uppercased.hasPrefix("UTC") || uppercased.hasPrefix("GMT") else {
            return nil
        }
        let suffix = String(uppercased.dropFirst(3))
        guard let sign = suffix.first, sign == "+" || sign == "-" else {
            return nil
        }
        let numeric = suffix.dropFirst().replacingOccurrences(of: ":", with: "")
        guard !numeric.isEmpty, let value = Int(numeric) else {
            return nil
        }
        let hours = value >= 100 ? value / 100 : value
        let minutes = value >= 100 ? value % 100 : 0
        let seconds = hours * 60 * 60 + minutes * 60
        return sign == "-" ? -seconds : seconds
    }
}
