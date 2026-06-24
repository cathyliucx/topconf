import Foundation
import SwiftData
import XCTest
@testable import TopConf

enum SwiftDataTestSupport {
    static func makeInMemoryContainer() throws -> ModelContainer {
        try SwiftDataContainerFactory.makeContainer(isStoredInMemoryOnly: true)
    }

    static func makePersistentContainer(testName: String) throws -> (container: ModelContainer, storeURL: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("TopConfSwiftDataTests", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let storeURL = directory.appendingPathComponent("\(sanitized(testName)).store")
        try removeStoreFiles(at: storeURL)
        return (try SwiftDataContainerFactory.makePersistentContainer(storeURL: storeURL), storeURL)
    }

    static func removeStoreFiles(at storeURL: URL) throws {
        let fileManager = FileManager.default
        let suffixes = ["", "-shm", "-wal"]
        for suffix in suffixes {
            let url = URL(fileURLWithPath: storeURL.path + suffix)
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
        }
    }

    private static func sanitized(_ testName: String) -> String {
        testName
            .replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "-", options: .regularExpression)
    }
}
