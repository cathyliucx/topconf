import Foundation

enum TrackedConferenceEntityMapper {
    static func makeEntity(from trackedConference: TrackedConference) -> TrackedConferenceEntity {
        TrackedConferenceEntity(
            conferenceID: trackedConference.conferenceID,
            addedAt: trackedConference.addedAt
        )
    }

    static func makeDomain(from entity: TrackedConferenceEntity) -> TrackedConference {
        TrackedConference(
            conferenceID: entity.conferenceID,
            addedAt: entity.addedAt
        )
    }
}
