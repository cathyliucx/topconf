import AppKit
import XCTest
@testable import TopConf

final class LauncherPanelLayoutTests: XCTestCase {
    override func tearDown() {
        NSApp.setActivationPolicy(.regular)
        super.tearDown()
    }

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

    func testMenuBarStatusItemUsesTemplateCalendarImageWithoutVisibleTitle() throws {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        defer {
            NSStatusBar.system.removeStatusItem(statusItem)
        }

        MenuBarStatusItem.configure(statusItem)
        let button = try XCTUnwrap(statusItem.button)
        let image = try XCTUnwrap(button.image)

        XCTAssertEqual(button.title, "")
        XCTAssertEqual(button.imagePosition, .imageOnly)
        XCTAssertTrue(image.isTemplate)
        XCTAssertEqual(button.accessibilityLabel(), "TopConf")
        XCTAssertEqual(button.toolTip, "TopConf")
    }

    @MainActor
    func testProductionLauncherInstallsImageStatusItemMenuAndAccessoryPolicy() throws {
        let coordinator = TopConfLauncherCoordinator(
            containerResult: .failure(LauncherTestError.startup),
            configuration: AppLaunchConfiguration(isUITesting: false, seedScenario: .none, initialSearchQuery: nil),
            registrar: LauncherSpyHotkeyRegistrar()
        )

        coordinator.start()
        defer {
            coordinator.stop()
            if let statusItem = coordinator.statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
            }
        }

        let statusItem = try XCTUnwrap(coordinator.statusItem)
        let button = try XCTUnwrap(statusItem.button)
        let menu = try XCTUnwrap(statusItem.menu)
        let showItem = try XCTUnwrap(menu.items.first { $0.title == "Show TopConf" })
        let quitItem = try XCTUnwrap(menu.items.first { $0.title == "Quit TopConf" })

        XCTAssertEqual(button.title, "")
        XCTAssertNotNil(button.image)
        XCTAssertTrue(button.image?.isTemplate ?? false)
        XCTAssertEqual(button.accessibilityLabel(), "TopConf")
        XCTAssertEqual(NSApp.activationPolicy(), .accessory)
        XCTAssertEqual(showItem.action, #selector(TopConfLauncherCoordinator.showPanel(_:)))
        XCTAssertTrue(showItem.target === coordinator)
        XCTAssertEqual(quitItem.action, #selector(TopConfLauncherCoordinator.quit(_:)))
        XCTAssertTrue(quitItem.target === coordinator)
    }
}

private enum LauncherTestError: Error {
    case startup
}

private final class LauncherSpyHotkeyRegistrar: GlobalHotkeyRegistering {
    func registerOptionSpace(_ handler: @escaping () -> Void) throws -> any HotkeyRegistrationToken {
        LauncherSpyHotkeyToken()
    }
}

private final class LauncherSpyHotkeyToken: HotkeyRegistrationToken {
    func invalidate() {}
}
