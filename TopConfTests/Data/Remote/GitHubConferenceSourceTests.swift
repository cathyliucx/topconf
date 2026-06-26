import Foundation
import XCTest
@testable import TopConf

final class GitHubConferenceSourceTests: XCTestCase {
    func testFetchesDirectoryListingAndProcessesEveryYAMLFile() async throws {
        let directory = try XCTUnwrap(URL(string: "https://example.test/AI"))
        let good = try XCTUnwrap(URL(string: "https://example.test/aaai.yml"))
        let second = try XCTUnwrap(URL(string: "https://example.test/icml.yaml"))
        let transport = MockRemoteDataTransport(responses: [
            directory: """
            [
              {"name":"aaai.yml","type":"file","download_url":"\(good.absoluteString)"},
              {"name":"notes.txt","type":"file","download_url":"https://example.test/notes.txt"},
              {"name":"icml.yaml","type":"file","download_url":"\(second.absoluteString)"},
              {"type":"dir","download_url":null}
            ]
            """,
            good: ConferenceYAMLParserTests.sampleForRemoteSource,
            second: ConferenceYAMLParserTests.sampleForRemoteSource.replacingOccurrences(of: "AAAI", with: "ICML")
        ])
        let source = GitHubConferenceSource(
            categoryDirectoryURLs: [directory],
            transport: transport,
            clock: FixedDateClock(now: DomainTestFactory.referenceDate),
            minimumSupportedConferenceCount: 1
        )

        let conferences = try await source.fetchConferences()

        XCTAssertEqual(conferences.map(\.id), ["ai-aaai", "ai-icml"])
        XCTAssertEqual(conferences.map(\.lastUpdatedAt), [DomainTestFactory.referenceDate, DomainTestFactory.referenceDate])
        XCTAssertEqual(source.lastDiagnostics.yamlFilesDiscovered, ["aaai.yml", "icml.yaml"])
        XCTAssertEqual(source.lastDiagnostics.yamlFilesDownloaded, ["aaai.yml", "icml.yaml"])
        XCTAssertEqual(source.lastDiagnostics.supportedFiles, ["aaai.yml", "icml.yaml"])
        XCTAssertEqual(source.lastDiagnostics.conferencesProduced, 2)
    }

    func testMultipleDirectoriesAreRequestedAndCombined() async throws {
        let ai = try XCTUnwrap(URL(string: "https://example.test/AI"))
        let cg = try XCTUnwrap(URL(string: "https://example.test/CG"))
        let aaai = try XCTUnwrap(URL(string: "https://example.test/aaai.yml"))
        let vis = try XCTUnwrap(URL(string: "https://example.test/vis.yml"))
        let transport = MockRemoteDataTransport(responses: [
            ai: """
            [{"name":"aaai.yml","path":"conference/AI/aaai.yml","type":"file","download_url":"\(aaai.absoluteString)"}]
            """,
            cg: """
            [{"name":"vis.yml","path":"conference/CG/vis.yml","type":"file","download_url":"\(vis.absoluteString)"}]
            """,
            aaai: ConferenceYAMLParserTests.sampleForRemoteSource,
            vis: ConferenceYAMLParserTests.sampleForRemoteSource
                .replacingOccurrences(of: "AAAI", with: "IEEE VIS")
                .replacingOccurrences(of: "sub: AI", with: "sub: CG")
        ])
        let source = GitHubConferenceSource(
            categoryDirectoryURLs: [ai, cg],
            transport: transport,
            clock: FixedDateClock(now: DomainTestFactory.referenceDate)
        )

        let conferences = try await source.fetchConferences()

        XCTAssertEqual(conferences.map(\.id), ["ai-aaai", "cg-vis"])
        XCTAssertEqual(source.lastDiagnostics.directoriesRequested, [ai.absoluteString, cg.absoluteString])
        XCTAssertEqual(source.lastDiagnostics.directoryListingsSucceeded, [ai.absoluteString, cg.absoluteString])
    }

    func testUnsupportedKDDIsReportedAndExcludedWithoutInvalidatingSupportedBatch() async throws {
        let directory = try XCTUnwrap(URL(string: "https://example.test/mixed"))
        let aaai = try XCTUnwrap(URL(string: "https://example.test/aaai.yml"))
        let kdd = try XCTUnwrap(URL(string: "https://example.test/sigkdd.yml"))
        let transport = MockRemoteDataTransport(responses: [
            directory: """
            [
              {"name":"aaai.yml","path":"conference/AI/aaai.yml","type":"file","download_url":"\(aaai.absoluteString)"},
              {"name":"sigkdd.yml","path":"conference/DB/sigkdd.yml","type":"file","download_url":"\(kdd.absoluteString)"}
            ]
            """,
            aaai: ConferenceYAMLParserTests.sampleForRemoteSource,
            kdd: ConferenceYAMLParserTests.kddArrayYAMLForRemoteSource
        ])
        let source = GitHubConferenceSource(
            categoryDirectoryURLs: [directory],
            transport: transport,
            clock: FixedDateClock(now: DomainTestFactory.referenceDate),
            minimumSupportedConferenceCount: 1
        )

        let conferences = try await source.fetchConferences()

        XCTAssertEqual(conferences.map(\.id), ["mixed-aaai"])
        XCTAssertEqual(source.lastDiagnostics.unsupportedFiles, ["conference/DB/sigkdd.yml"])
        XCTAssertEqual(source.lastDiagnostics.supportedFiles, ["conference/AI/aaai.yml"])
    }

    func testDuplicateFilePathsRejectBatch() async throws {
        let directory = try XCTUnwrap(URL(string: "https://example.test/AI"))
        let aaai = try XCTUnwrap(URL(string: "https://example.test/aaai.yml"))
        let source = GitHubConferenceSource(
            categoryDirectoryURLs: [directory],
            transport: MockRemoteDataTransport(responses: [
                directory: """
                [
                  {"name":"aaai.yml","path":"conference/AI/aaai.yml","type":"file","download_url":"\(aaai.absoluteString)"},
                  {"name":"aaai.yml","path":"conference/AI/aaai.yml","type":"file","download_url":"\(aaai.absoluteString)"}
                ]
                """,
                aaai: ConferenceYAMLParserTests.sampleForRemoteSource
            ]),
            clock: FixedDateClock(now: DomainTestFactory.referenceDate),
            minimumSupportedConferenceCount: 1
        )

        do {
            _ = try await source.fetchConferences()
            XCTFail("Expected duplicate file path rejection.")
        } catch {
            XCTAssertEqual(error as? RemoteCatalogError, .duplicateFilePath("conference/AI/aaai.yml"))
        }
    }

    func testMalformedSupportedYAMLRejectsBatch() async throws {
        let directory = try XCTUnwrap(URL(string: "https://example.test/AI"))
        let bad = try XCTUnwrap(URL(string: "https://example.test/bad.yml"))
        let source = GitHubConferenceSource(
            categoryDirectoryURLs: [directory],
            transport: MockRemoteDataTransport(responses: [
                directory: """
                [{"name":"bad.yml","path":"conference/AI/bad.yml","type":"file","download_url":"\(bad.absoluteString)"}]
                """,
                bad: "- malformed"
            ]),
            clock: FixedDateClock(now: DomainTestFactory.referenceDate),
            minimumSupportedConferenceCount: 1
        )

        do {
            _ = try await source.fetchConferences()
            XCTFail("Expected malformed YAML rejection.")
        } catch {
            XCTAssertEqual(error as? RemoteCatalogError, .malformedRoot)
            XCTAssertEqual(source.lastDiagnostics.rejectedFiles, ["conference/AI/bad.yml"])
        }
    }

    func testDirectoryListingFailureIsReportedAndRejectsBatch() async throws {
        let ai = try XCTUnwrap(URL(string: "https://example.test/AI"))
        let cg = try XCTUnwrap(URL(string: "https://example.test/CG"))
        let source = GitHubConferenceSource(
            categoryDirectoryURLs: [ai, cg],
            transport: MockRemoteDataTransport(responses: [
                ai: "[]"
            ]),
            clock: FixedDateClock(now: DomainTestFactory.referenceDate),
            minimumSupportedConferenceCount: 1
        )

        do {
            _ = try await source.fetchConferences()
            XCTFail("Expected directory listing failure.")
        } catch {
            XCTAssertEqual(error as? RemoteCatalogError, .invalidResponse(404))
            XCTAssertEqual(source.lastDiagnostics.directoriesRequested, [ai.absoluteString, cg.absoluteString])
            XCTAssertEqual(source.lastDiagnostics.directoryListingsSucceeded, [ai.absoluteString])
            XCTAssertEqual(source.lastDiagnostics.directoryListingFailures, [cg.absoluteString])
            XCTAssertFalse(source.lastDiagnostics.replacementAccepted)
        }
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
        XCTAssertEqual(conferences[0].category.sourceID, SeedConferenceCatalog.interdisciplinary.sourceID)
        XCTAssertEqual(conferences[0].ccfRank, .c)
    }

    func testThrowsWhenNoUsableConferenceExists() async throws {
        let directory = try XCTUnwrap(URL(string: "https://example.test/AI"))
        let source = GitHubConferenceSource(
            categoryDirectoryURLs: [directory],
            transport: MockRemoteDataTransport(responses: [directory: "[]"]),
            clock: FixedDateClock(now: DomainTestFactory.referenceDate),
            minimumSupportedConferenceCount: 1
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

    static let kddArrayYAMLForRemoteSource = """
    - title: SIGKDD
      description: ACM Knowledge Discovery and Data Mining
      sub: DB
      rank:
        ccf: A
      confs:
        - year: 2027
          id: sigkdd27
          link: https://kdd2027.kdd.org/
          timeline:
            - deadline: '2026-07-26 23:59:59'
          timezone: AoE
    """
}
