import Foundation
import XCTest
@testable import TopConf

final class GitHubConferenceSourceTests: XCTestCase {
    func testFetchesDirectoryListingAndSkipsMalformedFiles() async throws {
        let directory = try XCTUnwrap(URL(string: "https://example.test/AI"))
        let good = try XCTUnwrap(URL(string: "https://example.test/aaai.yml"))
        let bad = try XCTUnwrap(URL(string: "https://example.test/bad.yml"))
        let transport = MockRemoteDataTransport(responses: [
            directory: """
            [
              {"name":"aaai.yml","type":"file","download_url":"\(good.absoluteString)"},
              {"name":"bad.yml","type":"file","download_url":"\(bad.absoluteString)"},
              {"type":"dir","download_url":null}
            ]
            """,
            good: ConferenceYAMLParserTests.sampleForRemoteSource,
            bad: "- malformed"
        ])
        let source = GitHubConferenceSource(
            categoryDirectoryURLs: [directory],
            transport: transport,
            clock: FixedDateClock(now: DomainTestFactory.referenceDate)
        )

        let conferences = try await source.fetchConferences()

        XCTAssertEqual(conferences.map(\.id), ["ai-aaai"])
        XCTAssertEqual(conferences[0].lastUpdatedAt, DomainTestFactory.referenceDate)
    }

    func testFileIdentityKeepsIDStableAcrossYAMLMetadataChanges() async throws {
        let directory = try XCTUnwrap(URL(string: "https://example.test/AI"))
        let changedMetadata = try XCTUnwrap(URL(string: "https://example.test/renamed.yml"))
        let transport = MockRemoteDataTransport(responses: [
            directory: """
            [
              {"name":"neurips.yml","type":"file","download_url":"\(changedMetadata.absoluteString)"}
            ]
            """,
            changedMetadata: """
            title: NIPS-Renamed
            description: New Display Name
            sub: MX
            rank:
              ccf: C
            confs:
              - year: 2027
                id: nips27
                link: https://example.test/new
                timeline:
                  - deadline: '2026-07-27 23:59:59'
                timezone: UTC-12
            """
        ])
        let source = GitHubConferenceSource(
            categoryDirectoryURLs: [directory],
            transport: transport,
            clock: FixedDateClock(now: DomainTestFactory.referenceDate)
        )

        let conferences = try await source.fetchConferences()

        XCTAssertEqual(conferences.map(\.id), ["ai-neurips"])
        XCTAssertEqual(conferences[0].abbreviation, "NIPS-Renamed")
        XCTAssertEqual(conferences[0].category.sourceID, "MX")
        XCTAssertEqual(conferences[0].ccfRank, .c)
    }

    func testThrowsWhenNoUsableConferenceExists() async throws {
        let directory = try XCTUnwrap(URL(string: "https://example.test/AI"))
        let source = GitHubConferenceSource(
            categoryDirectoryURLs: [directory],
            transport: MockRemoteDataTransport(responses: [directory: "[]"]),
            clock: FixedDateClock(now: DomainTestFactory.referenceDate)
        )

        do {
            _ = try await source.fetchConferences()
            XCTFail("Expected no usable conferences error.")
        } catch {
            XCTAssertEqual(error as? RemoteCatalogError, .noUsableConferences)
        }
    }
}

private struct MockRemoteDataTransport: RemoteDataTransport {
    let responses: [URL: String]

    func data(from url: URL) async throws -> Data {
        guard let response = responses[url] else {
            throw RemoteCatalogError.invalidResponse(404)
        }
        return Data(response.utf8)
    }
}

extension ConferenceYAMLParserTests {
    static let sampleForRemoteSource = """
    title: AAAI
    description: AAAI Conference on Artificial Intelligence
    sub: AI
    rank:
      ccf: A
    confs:
      - year: 2027
        id: aaai27
        link: https://aaai.org/2027
        timeline:
          - deadline: '2026-07-27 23:59:59'
        timezone: UTC-12
    """
}
