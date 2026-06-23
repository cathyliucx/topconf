import Foundation

protocol ConferenceRepository {
    func loadAll() async throws -> [Conference]
    func conference(id: String) async throws -> Conference?
    func replaceAll(_ conferences: [Conference], updatedAt: Date) async throws
    func lastUpdatedAt() async throws -> Date?
}

protocol TrackedConferenceRepository {
    func loadAll() async throws -> [TrackedConference]
    func contains(conferenceID: String) async throws -> Bool
    func add(_ trackedConference: TrackedConference) async throws
    func remove(conferenceID: String) async throws
    func count() async throws -> Int
}

protocol ReminderRepository {
    func rules(for deadlineID: String) async throws -> [ReminderRule]
    func save(_ rule: ReminderRule) async throws
    func delete(ruleID: String) async throws
    func deleteAll(for deadlineID: String) async throws
}

