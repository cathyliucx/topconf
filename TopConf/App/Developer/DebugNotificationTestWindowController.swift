import AppKit
import SwiftUI

#if DEBUG
@MainActor
final class DebugNotificationTestWindowController {
    private var window: NSWindow?

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let viewModel = DebugNotificationTestViewModel(scheduler: UserNotificationScheduler())
        let hostingController = NSHostingController(rootView: DebugNotificationTestView(viewModel: viewModel))
        let window = NSWindow(contentViewController: hostingController)
        window.title = "TopConf Notification Test"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }
}
#endif
