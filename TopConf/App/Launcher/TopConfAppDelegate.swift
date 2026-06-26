import AppKit
import SwiftUI

@MainActor
final class TopConfAppDelegate: NSObject, NSApplicationDelegate {
    private var coordinator: TopConfLauncherCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let configuration = AppLaunchConfiguration.current()
        let containerResult = Result {
            try DependencyContainer.make(configuration: configuration)
        }
        let coordinator = TopConfLauncherCoordinator(
            containerResult: containerResult,
            configuration: configuration
        )
        self.coordinator = coordinator
        coordinator.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.stop()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        coordinator?.applicationDidBecomeActive()
    }
}

@MainActor
final class TopConfLauncherCoordinator: NSObject {
    private let configuration: AppLaunchConfiguration
    private let panelState = LauncherPanelState()
    private let panelController: LauncherPanelController
    private let hotkeyManager: GlobalHotkeyManager
    private var statusItem: NSStatusItem?
    private var hotkeyRegistrationError: Error?
    private var hasShownInitialUITestPanel = false
#if DEBUG
    private let debugNotificationTestWindowController = DebugNotificationTestWindowController()
#endif

    init(
        containerResult: Result<DependencyContainer, Error>,
        configuration: AppLaunchConfiguration,
        registrar: any GlobalHotkeyRegistering = CarbonGlobalHotkeyRegistrar()
    ) {
        self.configuration = configuration
        panelController = LauncherPanelController(
            rootView: Self.makeRootView(containerResult: containerResult, panelState: panelState),
            panelState: panelState,
            hidesOnDeactivate: !configuration.isUITesting,
            usesFloatingPanel: !configuration.isUITesting
        )
        hotkeyManager = GlobalHotkeyManager(registrar: registrar) { [weak panelController] in
            Task { @MainActor in
                panelController?.toggle()
            }
        }
        super.init()
    }

    func start() {
        NSApp.setActivationPolicy(configuration.isUITesting ? .regular : .accessory)
        installStatusItem()
        do {
            try hotkeyManager.start()
        } catch {
            hotkeyRegistrationError = error
        }
        if configuration.isUITesting {
            NSApp.activate(ignoringOtherApps: true)
            showInitialUITestPanelIfNeeded()
        }
    }

    func stop() {
        hotkeyManager.stop()
    }

    func applicationDidBecomeActive() {
        showInitialUITestPanelIfNeeded()
    }

    @objc
    func showPanel(_ sender: Any?) {
        panelController.show()
    }

    @objc
    func togglePanel(_ sender: Any?) {
        panelController.toggle()
    }

    @objc
    func quit(_ sender: Any?) {
        NSApp.terminate(sender)
    }

#if DEBUG
    @objc
    func showDebugNotificationTest(_ sender: Any?) {
        debugNotificationTestWindowController.show()
    }
#endif

    private func installStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "TopConf"
        statusItem.menu = makeMenu()
        self.statusItem = statusItem
    }

    private func showInitialUITestPanelIfNeeded() {
        guard configuration.isUITesting, !hasShownInitialUITestPanel else {
            return
        }
        hasShownInitialUITestPanel = true
        panelController.show()
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let showItem = NSMenuItem(title: "Show TopConf", action: #selector(showPanel(_:)), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)
#if DEBUG
        let developerMenu = NSMenu()
        let notificationTestItem = NSMenuItem(
            title: "Notification Test",
            action: #selector(showDebugNotificationTest(_:)),
            keyEquivalent: ""
        )
        notificationTestItem.target = self
        developerMenu.addItem(notificationTestItem)
        let developerItem = NSMenuItem(title: "Developer", action: nil, keyEquivalent: "")
        developerItem.submenu = developerMenu
        menu.addItem(developerItem)
#endif
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit TopConf", action: #selector(quit(_:)), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        return menu
    }

    private static func makeRootView(
        containerResult: Result<DependencyContainer, Error>,
        panelState: LauncherPanelState
    ) -> AnyView {
        switch containerResult {
        case let .success(container):
            return AnyView(AppRootView(container: container, panelState: panelState))
        case let .failure(error):
            return AnyView(
                EmptyStateView(
                    title: "TopConf could not start",
                    message: error.localizedDescription
                )
                .frame(minWidth: 420, minHeight: 240)
                .accessibilityIdentifier("topconf.error")
            )
        }
    }
}
