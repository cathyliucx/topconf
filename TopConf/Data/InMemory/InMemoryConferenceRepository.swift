import Foundation

actor InMemoryConferenceRepository: ConferenceRepository {
    private var conferencesByID: [String: Conference]
    private var updatedAt: Date?

    init(conferences: [Conference] = [], updatedAt: Date? = nil) {
        self.conferencesByID = Self.keyedByID(conferences)
        self.updatedAt = updatedAt
    }

    func loadAll() async throws -> [Conference] {
        conferencesByID.values.sorted { lhs, rhs in
            lhs.id < rhs.id
        }
    }

    func conference(id: String) async throws -> Conference? {
        conferencesByID[id]
    }

    func replaceAll(_ conferences: [Conference], updatedAt: Date) async throws {
        conferencesByID = Self.keyedByID(conferences)
        self.updatedAt = updatedAt
    }

    func lastUpdatedAt() async throws -> Date? {
        updatedAt
    }

    private static func keyedByID(_ conferences: [Conference]) -> [String: Conference] {
        var result: [String: Conference] = [:]
        for conference in conferences {
            result[conference.id] = conference
        }
        return result
    }
}
