import Foundation

enum TrackingResult: Equatable {
    case added
    case removed
    case alreadyTracked
    case notTracked
    case limitReached(maximum: Int)
    case conferenceNotFound
}

struct TrackingMutation: Equatable {
    let result: TrackingResult
    let trackedConferences: [TrackedConference]
}

struct ConferenceTrackingService {
    private let clock: any Clock

    init(clock: any Clock) {
        self.clock = clock
    }

    func add(
        conferenceID: String,
        to trackedConferences: [TrackedConference],
        availableConferences: [Conference]
    ) -> TrackingMutation {
        guard availableConferences.contains(where: { $0.id == conferenceID }) else {
            return TrackingMutation(result: .conferenceNotFound, trackedConferences: trackedConferences)
        }

        guard !trackedConferences.contains(where: { $0.conferenceID == conferenceID }) else {
            return TrackingMutation(result: .alreadyTracked, trackedConferences: trackedConferences)
        }

        guard trackedConferences.count < TrackingPolicy.maximumConferenceCount else {
            return TrackingMutation(
                result: .limitReached(maximum: TrackingPolicy.maximumConferenceCount),
                trackedConferences: trackedConferences
            )
        }

        let tracked = TrackedConference(conferenceID: conferenceID, addedAt: clock.now)
        return TrackingMutation(result: .added, trackedConferences: trackedConferences + [tracked])
    }

    func remove(conferenceID: String, from trackedConferences: [TrackedConference]) -> TrackingMutation {
        guard trackedConferences.contains(where: { $0.conferenceID == conferenceID }) else {
            return TrackingMutation(result: .notTracked, trackedConferences: trackedConferences)
        }

        return TrackingMutation(
            result: .removed,
            trackedConferences: trackedConferences.filter { $0.conferenceID != conferenceID }
        )
    }
}

struct ConferenceDiscoveryService {
    private let searchService: SearchService

    init(searchService: SearchService = SearchService()) {
        self.searchService = searchService
    }

    func discover(conferences: [Conference], filter: ConferenceDiscoveryFilter) -> [Conference] {
        let categoryFiltered = conferences.filter { conference in
            filter.categorySourceIDs.isEmpty || filter.categorySourceIDs.contains(conference.category.sourceID)
        }

        let rankFiltered = categoryFiltered.filter { conference in
            filter.ranks.isEmpty || filter.ranks.contains(conference.ccfRank)
        }

        return searchService.searchConferences(rankFiltered, query: filter.query)
    }
}

enum DeadlineSelection: Equatable {
    case future(edition: ConferenceEdition, deadline: Deadline)
    case toBeDetermined(edition: ConferenceEdition)
    case closed
    case sourceUnavailable

    var availability: ConferenceAvailability {
        switch self {
        case .future:
            return .available
        case .toBeDetermined:
            return .deadlineToBeDetermined
        case .closed:
            return .allDeadlinesClosed
        case .sourceUnavailable:
            return .sourceUnavailable
        }
    }

    var edition: ConferenceEdition? {
        switch self {
        case let .future(edition, _), let .toBeDetermined(edition):
            return edition
        case .closed, .sourceUnavailable:
            return nil
        }
    }

    var primaryDeadline: Deadline? {
        switch self {
        case let .future(_, deadline):
            return deadline
        case .toBeDetermined, .closed, .sourceUnavailable:
            return nil
        }
    }
}

struct DeadlineSelectionService {
    private let clock: any Clock
    private let calendar: Calendar

    init(clock: any Clock, calendar: Calendar = Calendar(identifier: .gregorian)) {
        self.clock = clock
        var calendar = calendar
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        self.calendar = calendar
    }

    func selectDeadline(for conference: Conference?) -> DeadlineSelection {
        guard let conference else {
            return .sourceUnavailable
        }

        let futureCandidates = conference.editions.flatMap { edition in
            edition.deadlines.compactMap { deadline -> (ConferenceEdition, Deadline, Date)? in
                guard let date = deadline.date, date > clock.now else {
                    return nil
                }
                return (edition, deadline, date)
            }
        }

        if let nearest = futureCandidates.sorted(by: compareDeadlineCandidates).first {
            return .future(edition: nearest.0, deadline: nearest.1)
        }

        if let tbdEdition = tbdEdition(in: conference.editions) {
            return .toBeDetermined(edition: tbdEdition)
        }

        return .closed
    }

    private func compareDeadlineCandidates(
        lhs: (ConferenceEdition, Deadline, Date),
        rhs: (ConferenceEdition, Deadline, Date)
    ) -> Bool {
        if lhs.2 != rhs.2 {
            return lhs.2 < rhs.2
        }
        if lhs.0.year != rhs.0.year {
            return lhs.0.year < rhs.0.year
        }
        return lhs.1.id < rhs.1.id
    }

    private func tbdEdition(in editions: [ConferenceEdition]) -> ConferenceEdition? {
        let currentYear = calendar.component(.year, from: clock.now)
        let tbdEditions = editions.filter { edition in
            edition.deadlines.contains(where: { $0.date == nil })
        }

        return tbdEditions.sorted { lhs, rhs in
            let lhsFuture = lhs.year >= currentYear
            let rhsFuture = rhs.year >= currentYear
            if lhsFuture != rhsFuture {
                return lhsFuture
            }
            if lhs.year != rhs.year {
                return lhs.year < rhs.year
            }
            return lhs.id < rhs.id
        }.first
    }
}

struct TrackedConferenceResolver {
    private let deadlineSelectionService: DeadlineSelectionService

    init(deadlineSelectionService: DeadlineSelectionService) {
        self.deadlineSelectionService = deadlineSelectionService
    }

    func resolve(
        trackedConference: TrackedConference,
        currentConferences: [Conference],
        lastKnownConferences: [Conference] = []
    ) -> ResolvedTrackedConference {
        let current = currentConferences.first { $0.id == trackedConference.conferenceID }
        let cached = lastKnownConferences.first { $0.id == trackedConference.conferenceID }

        guard let conference = current ?? cached else {
            return ResolvedTrackedConference(
                conferenceID: trackedConference.conferenceID,
                conference: nil,
                edition: nil,
                primaryDeadline: nil,
                availability: .sourceUnavailable
            )
        }

        let selection = deadlineSelectionService.selectDeadline(for: conference)
        return ResolvedTrackedConference(
            conferenceID: trackedConference.conferenceID,
            conference: conference,
            edition: selection.edition,
            primaryDeadline: selection.primaryDeadline,
            availability: selection.availability
        )
    }
}

struct ConferenceSortingService {
    func sort(_ conferences: [ResolvedTrackedConference]) -> [ResolvedTrackedConference] {
        conferences.sorted { lhs, rhs in
            let lhsPriority = priority(for: lhs)
            let rhsPriority = priority(for: rhs)

            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }

            if lhs.availability == .available, rhs.availability == .available {
                let lhsDate = lhs.primaryDeadline?.date
                let rhsDate = rhs.primaryDeadline?.date
                if lhsDate != rhsDate {
                    return (lhsDate ?? .distantFuture) < (rhsDate ?? .distantFuture)
                }
            }

            return abbreviation(for: lhs) < abbreviation(for: rhs)
        }
    }

    private func priority(for conference: ResolvedTrackedConference) -> Int {
        switch conference.availability {
        case .available:
            return 0
        case .deadlineToBeDetermined:
            return 1
        case .allDeadlinesClosed:
            return 2
        case .sourceUnavailable:
            return 3
        }
    }

    private func abbreviation(for conference: ResolvedTrackedConference) -> String {
        conference.conference?.abbreviation.lowercased() ?? conference.conferenceID.lowercased()
    }
}

enum DeadlineStatus: Equatable {
    case upcoming
    case closingSoon
    case closed
    case toBeDetermined
}

struct DeadlineCalculator {
    private let clock: any Clock

    init(clock: any Clock) {
        self.clock = clock
    }

    func status(for date: Date?) -> DeadlineStatus {
        guard let date else {
            return .toBeDetermined
        }

        let interval = date.timeIntervalSince(clock.now)
        if interval <= 0 {
            return .closed
        }
        if interval <= DeadlineUrgencyPolicy.closingSoonInterval {
            return .closingSoon
        }
        return .upcoming
    }

    func remainingText(until date: Date?) -> String {
        guard let date else {
            return "TBD"
        }

        let interval = date.timeIntervalSince(clock.now)
        guard interval > 0 else {
            return "Closed"
        }

        if interval >= 48 * 60 * 60 {
            return "\(Int(interval / (24 * 60 * 60))) days"
        }
        if interval >= 60 * 60 {
            return "\(Int(interval / (60 * 60))) hours"
        }
        return "\(max(1, Int(interval / 60))) min"
    }
}

struct SearchService {
    func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func searchConferences(_ conferences: [Conference], query: String) -> [Conference] {
        let normalizedQuery = normalize(query)
        guard !normalizedQuery.isEmpty else {
            return conferences
        }

        return conferences.filter { conference in
            matches(conference: conference, normalizedQuery: normalizedQuery)
        }
    }

    func matches(conference: Conference, normalizedQuery: String) -> Bool {
        normalize(conference.abbreviation).contains(normalizedQuery)
            || normalize(conference.fullName).contains(normalizedQuery)
            || conference.editions.contains { String($0.year).contains(normalizedQuery) }
    }
}
