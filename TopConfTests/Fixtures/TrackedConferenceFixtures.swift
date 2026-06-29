import Foundation
@testable import TopConf

enum TrackedConferenceFixtures {
    static func tracked(_ conferenceID: String) -> TrackedConference {
        TrackedConference(conferenceID: conferenceID, addedAt: DomainTestFactory.referenceDate)
    }

    static func trackedCatalog() -> [TrackedConference] {
        ConferenceFixtures.catalog().map { tracked($0.id) }
    }

    static func firstTen() -> [TrackedConference] {
        Array(trackedCatalog().prefix(TrackingPolicy.maximumConferenceCount))
    }

    static func missingFromCurrentCatalog() -> TrackedConference {
        tracked("ai-neurips")
    }
}
