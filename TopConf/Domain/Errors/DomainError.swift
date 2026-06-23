import Foundation

enum DomainError: Error, Equatable {
    case conferenceNotFound(String)
    case invalidConferenceData
}

