import Foundation

actor InMemoryTrackedConferenceRepository: TrackedConferenceRepository {
    private var trackedByConferenceID: [String: TrackedConference]

    init(trackedConferences: [TrackedConference] = []) {
        var result: [String: TrackedConference] = [:]
        for trackedConference in trackedConferences {
            result[trackedConference.conferenceID] = trackedConference
        }
        self.trackedByConferenceID = result
    }

    func loadAll() async throws -> [TrackedConference] {
        trackedByConferenceID.values.sorted { lhs, rhs in
            lhs.conferenceID < rhs.conferenceID
        }
    }

    func contains(conferenceID: String) async throws -> Bool {
        trackedByConferenceID[conferenceID] != nil
    }

    func add(_ trackedConference: TrackedConference) async throws {
        guard trackedByConferenceID[trackedConference.conferenceID] == nil else {
            return
        }
        trackedByConferenceID[trackedConference.conferenceID] = trackedConference
    }

    func remove(conferenceID: String) async throws {
        trackedByConferenceID.removeValue(forKey: conferenceID)
    }

    func count() async throws -> Int {
        trackedByConferenceID.count
    }
}
