import XCTest
@testable import TopConf

final class SwiftDataPersistenceRecreationTests: XCTestCase {
    func testRepositoriesPersistAcrossContainerRecreation() async throws {
        let persistentStore = try SwiftDataTestSupport.makePersistentContainer(testName: name)
        defer {
            try? SwiftDataTestSupport.removeStoreFiles(at: persistentStore.storeURL)
        }

        let firstConferenceRepository = SwiftDataConferenceRepository(container: persistentStore.container)
        let firstTrackedRepository = SwiftDataTrackedConferenceRepository(container: persistentStore.container)
        let firstReminderRepository = SwiftDataReminderRepository(container: persistentStore.container)

        try await firstConferenceRepository.replaceAll(ConferenceFixtures.catalog(), updatedAt: DomainTestFactory.referenceDate)
        try await firstTrackedRepository.add(TrackedConferenceFixtures.tracked("ai-neurips"))
        try await firstReminderRepository.save(ReminderFixtures.rule(offsetSeconds: 86_400))

        let recreatedContainer = try SwiftDataContainerFactory.makePersistentContainer(storeURL: persistentStore.storeURL)
        let secondConferenceRepository = SwiftDataConferenceRepository(container: recreatedContainer)
        let secondTrackedRepository = SwiftDataTrackedConferenceRepository(container: recreatedContainer)
        let secondReminderRepository = SwiftDataReminderRepository(container: recreatedContainer)

        let conferences = try await secondConferenceRepository.loadAll()
        let updatedAt = try await secondConferenceRepository.lastUpdatedAt()
        let tracked = try await secondTrackedRepository.loadAll()
        let reminders = try await secondReminderRepository.rules(for: ReminderFixtures.neuripsPaperDeadlineID)

        XCTAssertEqual(conferences.count, ConferenceFixtures.catalog().count)
        XCTAssertEqual(conferences.map(\.id), ConferenceFixtures.catalog().map(\.id).sorted())
        XCTAssertEqual(updatedAt, DomainTestFactory.referenceDate)
        XCTAssertEqual(tracked.map(\.conferenceID), ["ai-neurips"])
        XCTAssertEqual(reminders.map(\.id), ["topconf.ai-neurips-2026-paper.86400"])
    }
}
