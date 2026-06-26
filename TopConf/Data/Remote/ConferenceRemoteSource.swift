import Foundation

protocol ConferenceRemoteSource {
    func fetchConferences() async throws -> [Conference]
}

protocol RemoteDataTransport {
    func data(from url: URL) async throws -> Data
}

struct URLSessionRemoteDataTransport: RemoteDataTransport {
    func data(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw RemoteCatalogError.invalidResponse(httpResponse.statusCode)
        }
        return data
    }
}

enum RemoteCatalogError: Error, Equatable {
    case malformedRoot
    case noUsableConferences
    case invalidResponse(Int)
    case duplicateFilePath(String)
    case incompleteBatch(String)
}
