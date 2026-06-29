import Foundation

struct LastKnownConferenceSnapshot: Codable, Sendable {
    let conference: Conference
    let capturedAt: Date
}

protocol ConferenceCatalogSynchronizing {
    @discardableResult
    func refreshCatalog() async -> Bool
}

enum CatalogRefreshState: Equatable {
    case notStarted
    case inProgress
    case succeeded(lastSuccessfulRefreshAt: Date)
    case failed
    case rejected
}

final class ConferenceCatalogSynchronizer: ConferenceCatalogSynchronizing {
    private let remoteSource: any ConferenceRemoteSource
    private let conferenceRepository: any ConferenceRepository
    private let clock: any Clock
    private(set) var refreshState: CatalogRefreshState = .notStarted

    init(
        remoteSource: any ConferenceRemoteSource,
        conferenceRepository: any ConferenceRepository,
        clock: any Clock
    ) {
        self.remoteSource = remoteSource
        self.conferenceRepository = conferenceRepository
        self.clock = clock
    }

    @discardableResult
    func refreshCatalog() async -> Bool {
        refreshState = .inProgress
        do {
            let conferences = try await remoteSource.fetchConferences()
            guard !conferences.isEmpty else {
                refreshState = .rejected
                return false
            }
            try await conferenceRepository.replaceAll(conferences, updatedAt: clock.now)
            refreshState = .succeeded(lastSuccessfulRefreshAt: clock.now)
            return true
        } catch let error as RemoteCatalogError {
            switch error {
            case .noUsableConferences, .incompleteBatch, .duplicateFilePath, .malformedRoot, .unsupportedTimeZone:
                refreshState = .rejected
            case .invalidResponse:
                refreshState = .failed
            }
            return false
        } catch {
            refreshState = .failed
            return false
        }
    }
}
