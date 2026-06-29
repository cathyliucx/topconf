import Carbon
import Foundation

protocol HotkeyRegistrationToken: AnyObject {
    func invalidate()
}

protocol GlobalHotkeyRegistering {
    func registerOptionSpace(_ handler: @escaping () -> Void) throws -> any HotkeyRegistrationToken
}

final class GlobalHotkeyManager {
    private let registrar: any GlobalHotkeyRegistering
    private let onToggle: () -> Void
    private var token: (any HotkeyRegistrationToken)?

    init(registrar: any GlobalHotkeyRegistering, onToggle: @escaping () -> Void) {
        self.registrar = registrar
        self.onToggle = onToggle
    }

    func start() throws {
        guard token == nil else {
            return
        }
        token = try registrar.registerOptionSpace(onToggle)
    }

    func stop() {
        token?.invalidate()
        token = nil
    }
}

enum GlobalHotkeyError: Error {
    case installEventHandlerFailed(OSStatus)
    case registerHotkeyFailed(OSStatus)
}

final class CarbonGlobalHotkeyRegistrar: GlobalHotkeyRegistering {
    func registerOptionSpace(_ handler: @escaping () -> Void) throws -> any HotkeyRegistrationToken {
        try CarbonHotkeyRegistration(
            keyCode: UInt32(kVK_Space),
            modifiers: UInt32(optionKey),
            handler: handler
        )
    }
}

private final class CarbonHotkeyRegistration: HotkeyRegistrationToken {
    private var eventHandler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?
    private let handler: () -> Void

    init(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) throws {
        self.handler = handler

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(self).toOpaque()
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else {
                    return noErr
                }
                let registration = Unmanaged<CarbonHotkeyRegistration>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                registration.handler()
                return noErr
            },
            1,
            &eventType,
            userData,
            &eventHandler
        )
        guard handlerStatus == noErr else {
            throw GlobalHotkeyError.installEventHandlerFailed(handlerStatus)
        }

        let hotKeyID = EventHotKeyID(signature: fourCharacterCode("TPCF"), id: 1)
        let registrationStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
        guard registrationStatus == noErr else {
            invalidate()
            throw GlobalHotkeyError.registerHotkeyFailed(registrationStatus)
        }
    }

    deinit {
        invalidate()
    }

    func invalidate() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
}

private func fourCharacterCode(_ value: String) -> OSType {
    value.utf8.reduce(0) { partialResult, byte in
        (partialResult << 8) + OSType(byte)
    }
}
