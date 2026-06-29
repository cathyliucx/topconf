import Combine
import Foundation

enum ConferenceManagementLoadState: Equatable {
    case idle
    case loading
    case loaded
    case failed(String)
}

struct PresentationError: Equatable, Identifiable {
    let id: String
    let message: String
}

struct ConferenceRowPresentation: Identifiable, Equatable {
    let id: String
    let abbreviation: String
    let fullName: String
    let categorySourceID: String
    let categoryName: String
    let rank: CCFRank
    let isTracked: Bool
    let canAdd: Bool
}

struct CategoryFilterOption: Identifiable, Equatable {
    let id: String
    let title: String
    let accessibilityIdentifier: String
}

struct RankFilterOption: Identifiable, Equatable {
    let id: CCFRank
    let title: String
    let accessibilityIdentifier: String
}

@MainActor
final class ConferenceManagementViewModel: ObservableObject {
    @Published private(set) var loadState: ConferenceManagementLoadState = .idle
    @Published private(set) var allConferences: [ConferenceRowPresentation] = []
    @Published private(set) var discoveredConferences: [ConferenceRowPresentation] = []
    @Published private(set) var trackedConferences: [ConferenceRowPresentation] = []
    @Published private(set) var categoryOptions: [CategoryFilterOption] = []
    @Published private(set) var trackingCount = 0
    @Published private(set) var presentationError: PresentationError?
    @Published var selectedCategoryIDs: Set<String>
    @Published var selectedRanks: Set<CCFRank> = [.a]
    @Published var searchQuery = ""

    let maximumTrackingCount = TrackingPolicy.maximumConferenceCount
    let rankOptions: [RankFilterOption] = [
        RankFilterOption(id: .a, title: "CCF-A", accessibilityIdentifier: "topconf.filter.rank.a"),
        RankFilterOption(id: .b, title: "CCF-B", accessibilityIdentifier: "topconf.filter.rank.b"),
        RankFilterOption(id: .c, title: "CCF-C", accessibilityIdentifier: "topconf.filter.rank.c"),
        RankFilterOption(id: .unranked, title: "Unranked", accessibilityIdentifier: "topconf.filter.rank.unranked")
    ]

    private let conferenceRepository: any ConferenceRepository
    private let trackedRepository: any TrackedConferenceRepository
    private let trackingService: ConferenceTrackingService
    private let discoveryService: ConferenceDiscoveryService
    private let supportedCategoryIDs: Set<String>
    private var catalogConferences: [Conference] = []
    private var trackedRecords: [TrackedConference] = []
    private var isLoading = false

    init(
        conferenceRepository: any ConferenceRepository,
        trackedRepository: any TrackedConferenceRepository,
        trackingService: ConferenceTrackingService,
        discoveryService: ConferenceDiscoveryService = ConferenceDiscoveryService(),
        supportedCategoryIDs: Set<String> = SeedConferenceCatalog.supportedCategoryIDs
    ) {
        self.conferenceRepository = conferenceRepository
        self.trackedRepository = trackedRepository
        self.trackingService = trackingService
        self.discoveryService = discoveryService
        self.supportedCategoryIDs = supportedCategoryIDs
        self.selectedCategoryIDs = supportedCategoryIDs
    }

    var trackingCountText: String {
        "\(trackingCount) / \(maximumTrackingCount)"
    }

    var discoveryCountText: String {
        "\(discoveredConferences.count) results"
    }

    var availableConferences: [ConferenceRowPresentation] {
        discoveredConferences
    }

    var canAddAnotherConference: Bool {
        trackingCount < maximumTrackingCount
    }

    var canContinueOnboarding: Bool {
        trackingCount > 0
    }

    func load() async {
        guard !isLoading else {
            return
        }
        isLoading = true
        loadState = .loading
        defer { isLoading = false }

        do {
            catalogConferences = try await conferenceRepository.loadAll()
            trackedRecords = try await trackedRepository.loadAll()
            rebuildPresentation()
            loadState = .loaded
        } catch {
            loadState = .failed(error.localizedDescription)
            presentationError = PresentationError(id: "load", message: "Could not load conferences.")
        }
    }

    func refreshFilters() {
        rebuildPresentation()
    }

    func toggleCategory(_ categoryID: String) {
        if selectedCategoryIDs.contains(categoryID) {
            selectedCategoryIDs.remove(categoryID)
        } else {
            selectedCategoryIDs.insert(categoryID)
        }
        rebuildPresentation()
    }

    func toggleRank(_ rank: CCFRank) {
        if selectedRanks.contains(rank) {
            selectedRanks.remove(rank)
        } else {
            selectedRanks.insert(rank)
        }
        rebuildPresentation()
    }

    func addConference(id conferenceID: String) async {
        let trackedRecordsForCurrentCatalog = resolvableTrackedRecords()
        let mutation = trackingService.add(
            conferenceID: conferenceID,
            to: trackedRecordsForCurrentCatalog,
            availableConferences: catalogConferences
        )

        guard mutation.result == .added,
              let added = mutation.trackedConferences.first(where: { tracked in
                  !trackedRecordsForCurrentCatalog.contains(where: { $0.conferenceID == tracked.conferenceID })
              }) else {
            handleTrackingResult(mutation.result)
            return
        }

        do {
            try await trackedRepository.add(added)
            await load()
        } catch {
            presentationError = PresentationError(id: "add", message: "Could not add conference.")
        }
    }

    func removeConference(id conferenceID: String) async {
        let mutation = trackingService.remove(conferenceID: conferenceID, from: trackedRecords)
        guard mutation.result == .removed else {
            handleTrackingResult(mutation.result)
            return
        }

        do {
            try await trackedRepository.remove(conferenceID: conferenceID)
            await load()
        } catch {
            presentationError = PresentationError(id: "remove", message: "Could not remove conference.")
        }
    }

    func clearError() {
        presentationError = nil
    }

    private func rebuildPresentation() {
        let trackedRecordsForCurrentCatalog = resolvableTrackedRecords()
        let trackedIDs = Set(trackedRecordsForCurrentCatalog.map(\.conferenceID))
        trackingCount = trackedIDs.count
        categoryOptions = makeCategoryOptions(from: catalogConferences)
        allConferences = catalogConferences
            .sorted(by: compareConferences)
            .map { conference in
                makeRow(for: conference, trackedIDs: trackedIDs)
            }

        let filter = ConferenceDiscoveryFilter(
            categorySourceIDs: selectedCategoryIDs,
            ranks: selectedRanks,
            query: searchQuery
        )
        let discovered = discoveryService.discover(conferences: catalogConferences, filter: filter)
            .sorted(by: compareConferences)

        discoveredConferences = discovered.map { conference in
            makeRow(for: conference, trackedIDs: trackedIDs)
        }

        trackedConferences = trackedRecordsForCurrentCatalog
            .compactMap { tracked in
                catalogConferences.first(where: { $0.id == tracked.conferenceID })
            }
            .sorted(by: compareConferences)
            .map { conference in
                makeRow(for: conference, trackedIDs: trackedIDs)
            }
    }

    private func makeCategoryOptions(from conferences: [Conference]) -> [CategoryFilterOption] {
        let categoriesByID = Dictionary(grouping: conferences.map(\.category), by: \.sourceID)
            .compactMapValues(\.first)
        return supportedCategoryIDs.sorted().compactMap { id in
            guard let category = categoriesByID[id] else {
                return nil
            }
            return CategoryFilterOption(
                id: category.sourceID,
                title: category.displayName,
                accessibilityIdentifier: accessibilityIdentifier(forCategoryID: category.sourceID)
            )
        }
    }

    private func makeRow(for conference: Conference, trackedIDs: Set<String>) -> ConferenceRowPresentation {
        let isTracked = trackedIDs.contains(conference.id)
        return ConferenceRowPresentation(
            id: conference.id,
            abbreviation: conference.abbreviation,
            fullName: conference.fullName,
            categorySourceID: conference.category.sourceID,
            categoryName: conference.category.displayName,
            rank: conference.ccfRank,
            isTracked: isTracked,
            canAdd: !isTracked && canAddAnotherConference
        )
    }

    private func compareConferences(_ lhs: Conference, _ rhs: Conference) -> Bool {
        if lhs.abbreviation.localizedCaseInsensitiveCompare(rhs.abbreviation) != .orderedSame {
            return lhs.abbreviation.localizedCaseInsensitiveCompare(rhs.abbreviation) == .orderedAscending
        }
        return lhs.id < rhs.id
    }

    private func handleTrackingResult(_ result: TrackingResult) {
        switch result {
        case .added, .removed:
            return
        case .alreadyTracked:
            presentationError = PresentationError(id: "alreadyTracked", message: "Conference is already tracked.")
        case .notTracked:
            presentationError = PresentationError(id: "notTracked", message: "Conference is not tracked.")
        case let .limitReached(maximum):
            presentationError = PresentationError(id: "limitReached", message: "You can track up to \(maximum) conferences.")
        case .conferenceNotFound:
            presentationError = PresentationError(id: "conferenceNotFound", message: "Conference could not be found.")
        }
    }

    private func accessibilityIdentifier(forCategoryID categoryID: String) -> String {
        switch categoryID {
        case SeedConferenceCatalog.ai.sourceID:
            return "topconf.filter.category.ai"
        case SeedConferenceCatalog.graphics.sourceID:
            return "topconf.filter.category.graphics"
        case SeedConferenceCatalog.hci.sourceID:
            return "topconf.filter.category.hci"
        case SeedConferenceCatalog.interdisciplinary.sourceID:
            return "topconf.filter.category.interdisciplinary"
        default:
            return "topconf.filter.category.\(categoryID)"
        }
    }

    private func resolvableTrackedRecords() -> [TrackedConference] {
        let catalogIDs = Set(catalogConferences.map(\.id))
        return trackedRecords.filter { catalogIDs.contains($0.conferenceID) }
    }
}
