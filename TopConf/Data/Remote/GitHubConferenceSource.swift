import Foundation

struct RemoteCatalogDiagnostics: Equatable {
    var directoriesConfigured: [String] = []
    var directoriesRequested: [String] = []
    var directoryListingsSucceeded: [String] = []
    var directoryListingFailures: [String] = []
    var yamlFilesDiscovered: [String] = []
    var yamlFilesDownloaded: [String] = []
    var yamlFilesParsed: [String] = []
    var supportedFiles: [String] = []
    var unsupportedFiles: [String] = []
    var rejectedFiles: [String] = []
    var conferencesProduced = 0
    var editionsProduced = 0
    var deadlinesProduced = 0
    var replacementAccepted = false
}

final class GitHubConferenceSource: ConferenceRemoteSource {
    private struct ContentItem: Decodable {
        let name: String?
        let path: String?
        let type: String
        let downloadURL: URL?

        enum CodingKeys: String, CodingKey {
            case name
            case path
            case type
            case downloadURL = "download_url"
        }
    }

    private let categoryDirectoryURLs: [URL]
    private let transport: any RemoteDataTransport
    private let parser: ConferenceYAMLParser
    private let clock: any Clock
    private let minimumSupportedConferenceCount: Int
    private(set) var lastDiagnostics = RemoteCatalogDiagnostics()

    init(
        categoryDirectoryURLs: [URL] = GitHubConferenceSource.defaultCategoryDirectoryURLs,
        transport: any RemoteDataTransport = URLSessionRemoteDataTransport(),
        parser: ConferenceYAMLParser = ConferenceYAMLParser(),
        clock: any Clock = SystemClock(),
        minimumSupportedConferenceCount: Int? = nil
    ) {
        self.categoryDirectoryURLs = categoryDirectoryURLs
        self.transport = transport
        self.parser = parser
        self.clock = clock
        self.minimumSupportedConferenceCount = minimumSupportedConferenceCount ?? categoryDirectoryURLs.count
    }

    func fetchConferences() async throws -> [Conference] {
        var conferences: [Conference] = []
        var diagnostics = RemoteCatalogDiagnostics(
            directoriesConfigured: categoryDirectoryURLs.map(\.absoluteString)
        )
        var seenPaths: Set<String> = []

        for directoryURL in categoryDirectoryURLs {
            diagnostics.directoriesRequested.append(directoryURL.absoluteString)
            let listingData: Data
            do {
                listingData = try await transport.data(from: directoryURL)
            } catch {
                diagnostics.directoryListingFailures.append(directoryURL.absoluteString)
                lastDiagnostics = diagnostics
                throw error
            }
            diagnostics.directoryListingsSucceeded.append(directoryURL.absoluteString)
            let items = try JSONDecoder().decode([ContentItem].self, from: listingData)
            for item in items where item.type == "file" && Self.isYAML(item.name) {
                let filePath = item.path ?? item.name ?? item.downloadURL?.absoluteString ?? "unknown"
                guard seenPaths.insert(filePath).inserted else {
                    diagnostics.rejectedFiles.append(filePath)
                    lastDiagnostics = diagnostics
                    throw RemoteCatalogError.duplicateFilePath(filePath)
                }
                diagnostics.yamlFilesDiscovered.append(filePath)
                guard let url = item.downloadURL else {
                    diagnostics.rejectedFiles.append(filePath)
                    lastDiagnostics = diagnostics
                    throw RemoteCatalogError.incompleteBatch("Missing download URL for \(filePath)")
                }
                do {
                    let yamlData = try await transport.data(from: url)
                    diagnostics.yamlFilesDownloaded.append(filePath)
                    guard let yaml = String(data: yamlData, encoding: .utf8) else {
                        diagnostics.rejectedFiles.append(filePath)
                        lastDiagnostics = diagnostics
                        throw RemoteCatalogError.incompleteBatch("Invalid UTF-8 for \(filePath)")
                    }
                    let records = try parser.parseRecords(
                        yaml,
                        capturedAt: clock.now,
                        stableID: stableID(for: item, directoryURL: directoryURL)
                    )
                    diagnostics.yamlFilesParsed.append(filePath)
                    let supported = records.compactMap(\.conference)
                    if supported.isEmpty {
                        diagnostics.unsupportedFiles.append(filePath)
                    } else {
                        diagnostics.supportedFiles.append(filePath)
                        conferences.append(contentsOf: supported)
                    }
                } catch {
                    diagnostics.rejectedFiles.append(filePath)
                    lastDiagnostics = diagnostics
                    throw error
                }
            }
        }
        let deduplicated = Self.deduplicatedByID(conferences)
        diagnostics.conferencesProduced = deduplicated.count
        diagnostics.editionsProduced = deduplicated.flatMap(\.editions).count
        diagnostics.deadlinesProduced = deduplicated.flatMap(\.editions).flatMap(\.deadlines).count

        guard !deduplicated.isEmpty else {
            lastDiagnostics = diagnostics
            throw RemoteCatalogError.noUsableConferences
        }
        guard deduplicated.count >= minimumSupportedConferenceCount else {
            lastDiagnostics = diagnostics
            throw RemoteCatalogError.incompleteBatch("Only \(deduplicated.count) supported conferences were produced.")
        }

        diagnostics.replacementAccepted = true
        lastDiagnostics = diagnostics
        return deduplicated
    }

    private func stableID(for item: ContentItem, directoryURL: URL) -> String {
        let category = Self.slug(directoryURL.lastPathComponent)
        let fileName = item.name ?? item.downloadURL?.deletingPathExtension().lastPathComponent ?? "unknown"
        return "\(category)-\(Self.slug((fileName as NSString).deletingPathExtension))"
    }

    private static func slug(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics
        let scalars = value.lowercased().unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        return String(scalars)
            .split(separator: "-")
            .joined(separator: "-")
    }

    private static func isYAML(_ name: String?) -> Bool {
        guard let name = name?.lowercased() else {
            return false
        }
        return name.hasSuffix(".yml") || name.hasSuffix(".yaml")
    }

    private static func deduplicatedByID(_ conferences: [Conference]) -> [Conference] {
        var keyed: [String: Conference] = [:]
        for conference in conferences {
            keyed[conference.id] = conference
        }
        return keyed.values.sorted { $0.id < $1.id }
    }

    static let defaultCategoryDirectoryURLs: [URL] = [
        "AI",
        "CG",
        "HI",
        "MX"
    ].compactMap {
        URL(string: "https://api.github.com/repos/ccfddl/ccf-deadlines/contents/conference/\($0)")
    }
}
