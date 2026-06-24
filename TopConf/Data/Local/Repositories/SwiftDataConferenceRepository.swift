import Foundation
import SwiftData

actor SwiftDataConferenceRepository: ConferenceRepository {
    private let container: ModelContainer

    init(container: ModelContainer) {
        self.container = container
    }

    func loadAll() async throws -> [Conference] {
        let context = ModelContext(container)
        let descriptor = FetchDescriptor<ConferenceEntity>(
            sortBy: [SortDescriptor(\ConferenceEntity.id)]
        )
        return try context.fetch(descriptor).map(ConferenceEntityMapper.makeDomain(from:))
    }

    func conference(id: String) async throws -> Conference? {
        let context = ModelContext(container)
        var descriptor = FetchDescriptor<ConferenceEntity>(
            predicate: #Predicate { $0.id == id }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first.map(ConferenceEntityMapper.makeDomain(from:))
    }

    func replaceAll(_ conferences: [Conference], updatedAt: Date) async throws {
        let replacementEntities = Self.deduplicatedByID(conferences).map(ConferenceEntityMapper.makeEntity(from:))
        let context = ModelContext(container)

        try deleteAll(DeadlineEntity.self, in: context)
        try deleteAll(ConferenceEditionEntity.self, in: context)
        try deleteAll(ConferenceEntity.self, in: context)

        for entity in replacementEntities {
            context.insert(entity)
        }
        try upsertCatalogMetadata(updatedAt: updatedAt, in: context)
        try context.save()
    }

    func lastUpdatedAt() async throws -> Date? {
        let context = ModelContext(container)
        let metadataKey = SwiftDataContainerFactory.catalogMetadataKey
        var descriptor = FetchDescriptor<ConferenceCatalogMetadataEntity>(
            predicate: #Predicate { $0.key == metadataKey }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first?.lastSuccessfulCatalogUpdateAt
    }

    private func deleteAll<Model: PersistentModel>(_ modelType: Model.Type, in context: ModelContext) throws {
        let descriptor = FetchDescriptor<Model>()
        for entity in try context.fetch(descriptor) {
            context.delete(entity)
        }
    }

    private func upsertCatalogMetadata(updatedAt: Date, in context: ModelContext) throws {
        let metadataKey = SwiftDataContainerFactory.catalogMetadataKey
        var descriptor = FetchDescriptor<ConferenceCatalogMetadataEntity>(
            predicate: #Predicate { $0.key == metadataKey }
        )
        descriptor.fetchLimit = 1
        if let metadata = try context.fetch(descriptor).first {
            metadata.lastSuccessfulCatalogUpdateAt = updatedAt
        } else {
            context.insert(
                ConferenceCatalogMetadataEntity(
                    key: metadataKey,
                    lastSuccessfulCatalogUpdateAt: updatedAt
                )
            )
        }
    }

    private static func deduplicatedByID(_ conferences: [Conference]) -> [Conference] {
        var keyedConferences: [String: Conference] = [:]
        for conference in conferences {
            keyedConferences[conference.id] = conference
        }
        return keyedConferences.values.sorted { lhs, rhs in
            lhs.id < rhs.id
        }
    }
}
