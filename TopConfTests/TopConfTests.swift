import XCTest
@testable import TopConf

final class TopConfTests: XCTestCase {
    func testApplicationNameIsStable() {
        XCTAssertEqual("TopConf", "TopConf")
    }

    func testAppIconAssetContainsRequiredRepresentationsAndVectorSource() throws {
        let root = repositoryRoot()
        let appIconURL = root.appendingPathComponent("TopConf/Assets.xcassets/AppIcon.appiconset")
        let contentsURL = appIconURL.appendingPathComponent("Contents.json")
        let sourceURL = root.appendingPathComponent("TopConf/Assets/AppIcon/topconf-calendar-icon.svg")
        let data = try Data(contentsOf: contentsURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let images = try XCTUnwrap(json?["images"] as? [[String: String]])
        let filenames = Set(images.compactMap { $0["filename"] })

        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertEqual(images.count, 10)
        XCTAssertEqual(filenames, [
            "topconf-icon-16.png",
            "topconf-icon-32.png",
            "topconf-icon-64.png",
            "topconf-icon-128.png",
            "topconf-icon-256.png",
            "topconf-icon-512.png",
            "topconf-icon-1024.png"
        ])

        for filename in filenames {
            let fileURL = appIconURL.appendingPathComponent(filename)
            XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path), filename)
            XCTAssertGreaterThan(try Data(contentsOf: fileURL).count, 0, filename)
        }
    }

    func testProjectReferencesOnlyCurrentAppIconAsset() throws {
        let project = repositoryRoot().appendingPathComponent("TopConf.xcodeproj/project.pbxproj")
        let contents = try String(contentsOf: project)

        XCTAssertTrue(contents.contains("ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;"))
        XCTAssertFalse(contents.contains("OldIcon"))
        XCTAssertFalse(contents.contains("LegacyIcon"))
    }

    private func repositoryRoot(filePath: String = #filePath) -> URL {
        URL(fileURLWithPath: filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
