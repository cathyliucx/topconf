import Foundation
import SwiftData

@Model
final class ConferenceCatalogMetadataEntity {
    @Attribute(.unique) var key: String
    var lastSuccessfulCatalogUpdateAt: Date?

    init(key: String, lastSuccessfulCatalogUpdateAt: Date?) {
        self.key = key
        self.lastSuccessfulCatalogUpdateAt = lastSuccessfulCatalogUpdateAt
    }
}
