import Foundation

final class GitHubConferenceSource: ConferenceRemoteSource {
    private struct ContentItem: Decodable {
        let name: String?
        let type: String
        let downloadURL: URL?

        enum CodingKeys: String, CodingKey {
            case name
            case type
            case downloadURL = "download_url"
        }
    }

    private let categoryDirectoryURLs: [URL]
    private let transport: any RemoteDataTransport
    private let parser: ConferenceYAMLParser
    private let clock: any Clock

    init(
        categoryDirectoryURLs: [URL] = GitHubConferenceSource.defaultCategoryDirectoryURLs,
        transport: any RemoteDataTransport = URLSessionRemoteDataTransport(),
        parser: ConferenceYAMLParser = ConferenceYAMLParser(),
        clock: any Clock = SystemClock()
    ) {
        self.categoryDirectoryURLs = categoryDirectoryURLs
        self.transport = transport
        self.parser = parser
        self.clock = clock
    }

    func fetchConferences() async throws -> [Conference] {
        var conferences: [Conference] = []
        for directoryURL in categoryDirectoryURLs {
            let listingData = try await transport.data(from: directoryURL)
            let items = try JSONDecoder().decode([ContentItem].self, from: listingData)
            for item in items where item.type == "file" {
                guard let url = item.downloadURL else {
                    continue
                }
                do {
                    let yamlData = try await transport.data(from: url)
                    guard let yaml = String(data: yamlData, encoding: .utf8) else {
                        continue
                    }
                    conferences.append(try parser.parse(
                        yaml,
                        capturedAt: clock.now,
                        stableID: stableID(for: item, directoryURL: directoryURL)
                    ))
                } catch {
                    continue
                }
            }
        }
        guard !conferences.isEmpty else {
            throw RemoteCatalogError.noUsableConferences
        }
        return conferences.sorted { $0.id < $1.id }
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

    static let defaultCategoryDirectoryURLs: [URL] = [
        "AI",
        "CG",
        "HI",
        "MX"
    ].compactMap {
        URL(string: "https://api.github.com/repos/ccfddl/ccf-deadlines/contents/conference/\($0)")
    }
}
