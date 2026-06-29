import XCTest
@testable import TopConf

final class FixtureDrivenDomainTests: XCTestCase {
    private let deadlineSelection = DeadlineSelectionService(clock: FixedClock.standard)
    private let discovery = ConferenceDiscoveryService()
    private let tracking = ConferenceTrackingService(clock: FixedClock.standard)
    private let sorting = ConferenceSortingService()
    private let search = SearchService()

    func testDeadlineSelectionWithRealisticFixtures() {
        let multiDeadline = deadlineSelection.selectDeadline(for: ConferenceFixtures.multipleDeadlineConference())
        let abstractPassedPaperOpen = deadlineSelection.selectDeadline(for: ConferenceFixtures.multipleDeadlineConference())

        XCTAssertEqual(multiDeadline.primaryDeadline?.type, .paper)
        XCTAssertEqual(abstractPassedPaperOpen.primaryDeadline?.id, "hci-chi-2026-paper")
    }

    func testSortingFutureTBDClosedAndUnavailableFixtures() {
        let resolver = TrackedConferenceResolver(deadlineSelectionService: deadlineSelection)
        let current = [
            ConferenceFixtures.closedConference(),
            ConferenceFixtures.tbdConference(),
            ConferenceFixtures.multipleDeadlineConference()
        ]
        let tracked = [
            TrackedConferenceFixtures.tracked("missing-current"),
            TrackedConferenceFixtures.tracked("interdisciplinary-www"),
            TrackedConferenceFixtures.tracked("graphics-siggraph"),
            TrackedConferenceFixtures.tracked("hci-chi")
        ]
        let resolved = tracked.map {
            resolver.resolve(trackedConference: $0, currentConferences: current)
        }

        XCTAssertEqual(sorting.sort(resolved).map(\.conferenceID), [
            "hci-chi",
            "graphics-siggraph",
            "interdisciplinary-www",
            "missing-current"
        ])
    }

    func testStableTrackingIdentityAcrossUpstreamChangesAndCacheFallback() {
        let resolver = TrackedConferenceResolver(deadlineSelectionService: deadlineSelection)
        let tracked = TrackedConferenceFixtures.tracked("ai-neurips")

        XCTAssertEqual(resolver.resolve(trackedConference: tracked, currentConferences: [ConferenceFixtures.renamedNeurIPS()]).conference?.fullName, "Renamed Neural Information Processing Conference")
        XCTAssertEqual(resolver.resolve(trackedConference: tracked, currentConferences: [ConferenceFixtures.categoryChangedNeurIPS()]).conference?.category, ConferenceFixtures.interdisciplinary)
        XCTAssertEqual(resolver.resolve(trackedConference: tracked, currentConferences: [ConferenceFixtures.rankChangedNeurIPS()]).conference?.ccfRank, .b)
        XCTAssertEqual(
            resolver.resolve(
                trackedConference: tracked,
                currentConferences: [],
                lastKnownConferences: [ConferenceFixtures.lastKnownFallbackConference()]
            ).availability,
            .available
        )
    }

    func testTrackingLimitWithElevenFixtureConferences() {
        let catalog = ConferenceFixtures.catalog()
        let nine = catalog.prefix(9).map { TrackedConferenceFixtures.tracked($0.id) }

        let tenth = tracking.add(conferenceID: catalog[9].id, to: nine, availableConferences: catalog)
        let eleventh = tracking.add(conferenceID: catalog[10].id, to: tenth.trackedConferences, availableConferences: catalog)

        XCTAssertEqual(tenth.result, .added)
        XCTAssertEqual(tenth.trackedConferences.count, TrackingPolicy.maximumConferenceCount)
        XCTAssertEqual(eleventh.result, .limitReached(maximum: TrackingPolicy.maximumConferenceCount))
    }

    func testDiscoveryAndSearchAcrossFixtureCatalog() {
        let catalog = ConferenceFixtures.catalog()
        let discovered = discovery.discover(
            conferences: catalog,
            filter: ConferenceDiscoveryFilter(
                categorySourceIDs: [ConferenceFixtures.ai.sourceID, ConferenceFixtures.hci.sourceID],
                ranks: [.a],
                query: ""
            )
        )

        XCTAssertTrue(discovered.map(\.id).contains("ai-neurips"))
        XCTAssertTrue(discovered.map(\.id).contains("hci-chi"))
        XCTAssertEqual(search.searchConferences(catalog, query: "siggraph").map(\.id), ["graphics-siggraph"])
        XCTAssertEqual(search.searchConferences(catalog, query: "Human Factors").map(\.id), ["hci-chi"])
        XCTAssertEqual(search.searchConferences(catalog, query: "2027").map(\.id).sorted(), ["ai-iclr", "graphics-siggraph"])
    }
}
