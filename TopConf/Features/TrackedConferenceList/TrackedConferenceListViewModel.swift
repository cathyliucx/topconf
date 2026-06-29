import Combine
import Foundation

enum TrackedConferenceListLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}

@MainActor
final class TrackedConferenceListViewModel: ObservableObject {
    @Published private(set) var loadState: TrackedConferenceListLoadState = .idle
    @Published private(set) var rows: [TrackedConferenceRowPresentation] = []
    @Published private(set) var visibleRows: [TrackedConferenceRowPresentation] = []
    @Published private(set) var presentationError: PresentationError?
    @Published private(set) var lastUpdatedText: String = "Updated -"
    @Published var searchQuery = ""

    private let conferenceRepository: any ConferenceRepository
    private let trackedRepository: any TrackedConferenceRepository
    private let resolver: TrackedConferenceResolver
    private let sortingService: ConferenceSortingService
    private let deadlineCalculator: DeadlineCalculator
    private let searchService: SearchService
    private let lastKnownConferences: [Conference]
    private let reminderManager: (any DeadlineReminderManaging)?
    private var isLoading = false

    init(
        conferenceRepository: any ConferenceRepository,
        trackedRepository: any TrackedConferenceRepository,
        resolver: TrackedConferenceResolver,
        sortingService: ConferenceSortingService = ConferenceSortingService(),
        deadlineCalculator: DeadlineCalculator,
        searchService: SearchService = SearchService(),
        lastKnownConferences: [Conference] = [],
        reminderManager: (any DeadlineReminderManaging)? = nil
    ) {
        self.conferenceRepository = conferenceRepository
        self.trackedRepository = trackedRepository
        self.resolver = resolver
        self.sortingService = sortingService
        self.deadlineCalculator = deadlineCalculator
        self.searchService = searchService
        self.lastKnownConferences = lastKnownConferences
        self.reminderManager = reminderManager
    }

    var isEmpty: Bool {
        loadState == .loaded && rows.isEmpty
    }

    var trackingCountText: String {
        let resolvableCount = rows.filter { $0.availability != .sourceUnavailable }.count
        return "\(resolvableCount) / \(TrackingPolicy.maximumConferenceCount)"
    }

    func load() async {
        guard !isLoading else {
            return
        }
        isLoading = true
        if rows.isEmpty {
            loadState = .loading
        }
        defer { isLoading = false }

        do {
            let tracked = try await trackedRepository.loadAll()
            let catalog = try await conferenceRepository.loadAll()
            let updatedAt = try await conferenceRepository.lastUpdatedAt()
            let catalogIDs = Set(catalog.map(\.id))
            let resolved = tracked.filter { catalogIDs.contains($0.conferenceID) }.map { trackedConference in
                resolver.resolve(
                    trackedConference: trackedConference,
                    currentConferences: catalog,
                    lastKnownConferences: []
                )
            }
            rows = sortingService.sort(resolved).map(makeRow)
            lastUpdatedText = Self.lastUpdatedText(for: updatedAt)
            applySearch()
            await reminderManager?.synchronizeReminders(for: rows.compactMap(\.reminderContext))
            loadState = .loaded
            presentationError = nil
        } catch {
            loadState = .failed("Could not load tracked conferences.")
            presentationError = PresentationError(id: "loadTracked", message: "Could not load tracked conferences.")
            applySearch()
        }
    }

    func retry() async {
        await load()
    }

    func refreshSearch() {
        applySearch()
    }

    func clearSearch() {
        searchQuery = ""
        applySearch()
    }

    private func applySearch() {
        let normalizedQuery = searchService.normalize(searchQuery)
        guard !normalizedQuery.isEmpty else {
            visibleRows = rows
            return
        }

        visibleRows = rows.filter { row in
            searchService.normalize(row.abbreviation).contains(normalizedQuery)
                || searchService.normalize(row.fullName).contains(normalizedQuery)
                || row.editionYearText.contains(normalizedQuery)
                || searchService.normalize(row.id).contains(normalizedQuery)
        }
    }

    private func makeRow(for resolved: ResolvedTrackedConference) -> TrackedConferenceRowPresentation {
        let conference = resolved.conference
        let deadline = DeadlinePresentation.make(
            deadline: resolved.primaryDeadline,
            availability: resolved.availability,
            calculator: deadlineCalculator
        )
        return TrackedConferenceRowPresentation(
            id: resolved.conferenceID,
            trackedStateText: "Tracked",
            abbreviation: conference?.abbreviation ?? resolved.conferenceID,
            fullName: conference?.fullName ?? "Conference source unavailable",
            editionYearText: resolved.edition.map { String($0.year) } ?? "-",
            deadline: deadline,
            websiteURL: conference?.websiteURL,
            availability: resolved.availability,
            reminderContext: Self.reminderContext(
                for: resolved,
                conference: conference,
                deadline: deadline
            )
        )
    }

    func makeReminderViewModel(for row: TrackedConferenceRowPresentation) -> ReminderViewModel? {
        guard let reminderContext = row.reminderContext, let reminderManager else {
            return nil
        }
        return ReminderViewModel(context: reminderContext, reminderManager: reminderManager)
    }

    private static func reminderContext(
        for resolved: ResolvedTrackedConference,
        conference: Conference?,
        deadline presentation: DeadlinePresentation
    ) -> DeadlineReminderContext? {
        guard let deadline = resolved.primaryDeadline else {
            return nil
        }
        let title = conference.map { "\($0.abbreviation) \($0.fullName)" } ?? resolved.conferenceID
        return DeadlineReminderContext(
            deadlineID: deadline.id,
            conferenceTitle: title,
            deadlineTypeText: presentation.typeText,
            deadlineDate: deadline.date,
            availability: resolved.availability
        )
    }

    private static func lastUpdatedText(for date: Date?) -> String {
        guard let date else {
            return "Updated -"
        }
        let formatted = TopConfDateFormatting.compactDateTime(
            date,
            timeZone: TimeZone(secondsFromGMT: 0) ?? .current,
            includeYear: true
        )
        return "Updated \(formatted) UTC"
    }
}
