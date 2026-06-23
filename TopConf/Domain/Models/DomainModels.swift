import Foundation

struct Conference: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let abbreviation: String
    let fullName: String
    let category: ConferenceCategory
    let ccfRank: CCFRank
    let websiteURL: URL?
    let editions: [ConferenceEdition]
    let lastUpdatedAt: Date?
}

struct ConferenceEdition: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let conferenceID: String
    let year: Int
    let conferenceStartDate: Date?
    let conferenceEndDate: Date?
    let location: String?
    let deadlines: [Deadline]
}

struct Deadline: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let editionID: String
    let type: DeadlineType
    let date: Date?
    let originalTimeZoneIdentifier: String?
    let rawDateValue: String?
    let comment: String?
}

enum DeadlineType: String, Codable, Hashable, Sendable {
    case abstract
    case paper
    case supplementary
    case rebuttal
    case cameraReady
    case registration
    case other
}

struct ConferenceCategory: Codable, Hashable, Sendable {
    let sourceID: String
    let displayName: String
}

enum CCFRank: String, Codable, CaseIterable, Sendable {
    case a
    case b
    case c
    case unranked
    case unknown
}

struct TrackedConference: Identifiable, Codable, Hashable, Sendable {
    var id: String { conferenceID }

    let conferenceID: String
    let addedAt: Date
}

enum ConferenceAvailability: Equatable, Codable, Sendable {
    case available
    case deadlineToBeDetermined
    case allDeadlinesClosed
    case sourceUnavailable
}

struct ConferenceDiscoveryFilter: Equatable, Sendable {
    var categorySourceIDs: Set<String>
    var ranks: Set<CCFRank>
    var query: String
}

struct ResolvedTrackedConference: Identifiable, Equatable, Sendable {
    var id: String { conferenceID }

    let conferenceID: String
    let conference: Conference?
    let edition: ConferenceEdition?
    let primaryDeadline: Deadline?
    let availability: ConferenceAvailability
}

struct ReminderRule: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let deadlineID: String
    let offsetSeconds: TimeInterval
}

