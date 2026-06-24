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
    private var isLoading = false

    init(
        conferenceRepository: any ConferenceRepository,
        trackedRepository: any TrackedConferenceRepository,
        resolver: TrackedConferenceResolver,
        sortingService: ConferenceSortingService = ConferenceSortingService(),
        deadlineCalculator: DeadlineCalculator,
        searchService: SearchService = SearchService(),
        lastKnownConferences: [Conference] = []
    ) {
        self.conferenceRepository = conferenceRepository
        self.trackedRepository = trackedRepository
        self.resolver = resolver
        self.sortingService = sortingService
        self.deadlineCalculator = deadlineCalculator
        self.searchService = searchService
        self.lastKnownConferences = lastKnownConferences
    }

    var isEmpty: Bool {
        loadState == .loaded && rows.isEmpty
    }

    var trackingCountText: String {
        "\(rows.count) / \(TrackingPolicy.maximumConferenceCount)"
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
            let resolved = tracked.map { trackedConference in
                resolver.resolve(
                    trackedConference: trackedConference,
                    currentConferences: catalog,
                    lastKnownConferences: lastKnownConferences
                )
            }
            rows = sortingService.sort(resolved).map(makeRow)
            lastUpdatedText = Self.lastUpdatedText(for: updatedAt)
            applySearch()
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
