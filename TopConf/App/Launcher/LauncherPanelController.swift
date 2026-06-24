import AppKit
import SwiftUI

struct LauncherPanelLayout {
    static let defaultSize = NSSize(width: 960, height: 580)
    static let minimumSize = NSSize(width: 760, height: 420)

    static func centeredFrame(screenFrame: NSRect, panelSize: NSSize = defaultSize) -> NSRect {
        let width = min(panelSize.width, screenFrame.width)
        let height = min(panelSize.height, screenFrame.height)
        return NSRect(
            x: screenFrame.midX - width / 2,
            y: screenFrame.midY - height / 2,
            width: width,
            height: height
        )
    }
}

@MainActor
final class LauncherPanelController {
    private let rootView: AnyView
    private let panelState: LauncherPanelState
    private var panel: LauncherPanel?

    init(rootView: AnyView, panelState: LauncherPanelState) {
        self.rootView = rootView
        self.panelState = panelState
    }

    var isVisible: Bool {
        panel?.isVisible == true
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        let panel = panel ?? makePanel()
        self.panel = panel
        panelState.requestSearchFocus()
        panel.setFrame(LauncherPanelLayout.centeredFrame(screenFrame: activeScreenFrame()), display: true)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> LauncherPanel {
        let panel = LauncherPanel(
            contentRect: LauncherPanelLayout.centeredFrame(screenFrame: activeScreenFrame()),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = true
        panel.isReleasedWhenClosed = false
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.minSize = LauncherPanelLayout.minimumSize
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.setAccessibilityIdentifier("topconf.launcher.panel")
        panel.contentView = hostingView
        return panel
    }

    private func activeScreenFrame() -> NSRect {
        let mouseLocation = NSEvent.mouseLocation
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
            return screen.visibleFrame
        }
        return NSScreen.main?.visibleFrame ?? NSScreen.screens.first?.visibleFrame ?? .zero
    }
}

private final class LauncherPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }

    override func cancelOperation(_ sender: Any?) {
        orderOut(sender)
    }
}
