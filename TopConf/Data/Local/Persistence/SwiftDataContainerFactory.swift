import Foundation
import SwiftData

enum SwiftDataContainerFactory {
    static let catalogMetadataKey = "conferenceCatalog"

    static var schema: Schema {
        Schema([
            ConferenceEntity.self,
            ConferenceEditionEntity.self,
            DeadlineEntity.self,
            TrackedConferenceEntity.self,
            ReminderEntity.self,
            ConferenceCatalogMetadataEntity.self
        ])
    }

    static func makeContainer(isStoredInMemoryOnly: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: isStoredInMemoryOnly)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func makePersistentContainer(storeURL: URL) throws -> ModelContainer {
        let configuration = ModelConfiguration("TopConf", schema: schema, url: storeURL)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
