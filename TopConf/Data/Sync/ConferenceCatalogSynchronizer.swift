import Foundation

struct LastKnownConferenceSnapshot: Codable, Sendable {
    let conference: Conference
    let capturedAt: Date
}

protocol ConferenceCatalogSynchronizing {
    @discardableResult
    func refreshCatalog() async -> Bool
}

final class ConferenceCatalogSynchronizer: ConferenceCatalogSynchronizing {
    private let remoteSource: any ConferenceRemoteSource
    private let conferenceRepository: any ConferenceRepository
    private let clock: any Clock

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
        do {
            let conferences = try await remoteSource.fetchConferences()
            guard !conferences.isEmpty else {
                return false
            }
            try await conferenceRepository.replaceAll(conferences, updatedAt: clock.now)
            return true
        } catch {
            return false
        }
    }
}
