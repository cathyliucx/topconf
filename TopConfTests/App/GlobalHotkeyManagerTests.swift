import XCTest
@testable import TopConf

final class GlobalHotkeyManagerTests: XCTestCase {
    func testStartRegistersOptionSpaceAndInvokesToggleCallback() throws {
        let registrar = SpyHotkeyRegistrar()
        var toggleCount = 0
        let manager = GlobalHotkeyManager(registrar: registrar) {
            toggleCount += 1
        }

        try manager.start()
        registrar.invokeHandler()

        XCTAssertEqual(registrar.registrationCount, 1)
        XCTAssertEqual(toggleCount, 1)
    }

    func testStartIsIdempotentUntilStopped() throws {
        let registrar = SpyHotkeyRegistrar()
        let manager = GlobalHotkeyManager(registrar: registrar) {}

        try manager.start()
        try manager.start()

        XCTAssertEqual(registrar.registrationCount, 1)
    }

    func testStopInvalidatesRegistration() throws {
        let registrar = SpyHotkeyRegistrar()
        let manager = GlobalHotkeyManager(registrar: registrar) {}

        try manager.start()
        manager.stop()

        XCTAssertTrue(registrar.token.invalidated)
    }
}

private final class SpyHotkeyRegistrar: GlobalHotkeyRegistering {
    let token = SpyHotkeyToken()
    private var handler: (() -> Void)?
    private(set) var registrationCount = 0

    func registerOptionSpace(_ handler: @escaping () -> Void) throws -> any HotkeyRegistrationToken {
        registrationCount += 1
        self.handler = handler
        return token
    }

    func invokeHandler() {
        handler?()
    }
}

private final class SpyHotkeyToken: HotkeyRegistrationToken {
    private(set) var invalidated = false

    func invalidate() {
        invalidated = true
    }
}
