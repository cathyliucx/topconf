import AppKit
import XCTest
@testable import TopConf

final class LauncherPanelLayoutTests: XCTestCase {
    func testDefaultPanelFrameIsCenteredInScreenVisibleFrame() {
        let screenFrame = NSRect(x: 100, y: 200, width: 1600, height: 1000)

        let frame = LauncherPanelLayout.centeredFrame(screenFrame: screenFrame)

        XCTAssertEqual(frame.size, LauncherPanelLayout.defaultSize)
        XCTAssertEqual(frame.midX, screenFrame.midX)
        XCTAssertEqual(frame.midY, screenFrame.midY)
    }

    func testPanelFrameDoesNotExceedSmallScreenFrame() {
        let screenFrame = NSRect(x: 0, y: 0, width: 800, height: 500)

        let frame = LauncherPanelLayout.centeredFrame(screenFrame: screenFrame)

        XCTAssertEqual(frame.width, 800)
        XCTAssertEqual(frame.height, 500)
        XCTAssertEqual(frame.midX, screenFrame.midX)
        XCTAssertEqual(frame.midY, screenFrame.midY)
    }
}
