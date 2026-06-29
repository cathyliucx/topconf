import Foundation
import SwiftData

actor SwiftDataTrackedConferenceRepository: TrackedConferenceRepository {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func loadAll() async throws -> [TrackedConference] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<TrackedConferenceEntity>(
            sortBy: [SortDescriptor(\TrackedConferenceEntity.conferenceID)]
        )
        return try context.fetch(descriptor).map(TrackedConferenceEntityMapper.makeDomain(from:))
    }

    func contains(conferenceID: String) async throws -> Bool {
        let context = ModelContext(container)
        return try entity(conferenceID: conferenceID, in: context) != nil
    }

    func add(_ trackedConference: TrackedConference) async throws {
        let context = ModelContext(container)
        guard try entity(conferenceID: trackedConference.conferenceID, in: context) == nil else {
            return
        }
        context.insert(TrackedConferenceEntityMapper.makeEntity(from: trackedConference))
        try context.save()
    }

    func remove(conferenceID: String) async throws {
        let context = ModelContext(container)
        if let existing = try entity(conferenceID: conferenceID, in: context) {
            context.delete(existing)
            try context.save()
        }
    }

    func count() async throws -> Int {
        let context = ModelContext(container)
        return try context.fetchCount(FetchDescriptor<TrackedConferenceEntity>())
    }

    private func entity(conferenceID: String, in context: ModelContext) throws -> TrackedConferenceEntity? {
        var descriptor = FetchDescriptor<TrackedConferenceEntity>(
            predicate: #Predicate { $0.conferenceID == conferenceID }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}
