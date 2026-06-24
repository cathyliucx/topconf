import Foundation

struct TrackedConferenceRowPresentation: Identifiable, Equatable {
    let id: String
    let trackedStateText: String
    let abbreviation: String
    let fullName: String
    let editionYearText: String
    let deadline: DeadlinePresentation
    let websiteURL: URL?
    let availability: ConferenceAvailability
}
