import XCTest
@testable import TopConf

final class TopConfTests: XCTestCase {
    func testApplicationNameIsStable() {
        XCTAssertEqual("TopConf", "TopConf")
    }
}

