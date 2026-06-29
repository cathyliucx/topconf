import AppKit

enum MenuBarStatusItem {
    static let imageName = "MenuBarCalendar"
    static let accessibilityLabel = "TopConf"
    static let toolTip = "TopConf"

    static func makeImage() -> NSImage? {
        let image = NSImage(named: NSImage.Name(imageName))
        image?.isTemplate = true
        return image
    }

    static func configure(_ statusItem: NSStatusItem) {
        statusItem.length = NSStatusItem.squareLength
        guard let button = statusItem.button else {
            return
        }
        button.title = ""
        button.image = makeImage()
        button.imagePosition = .imageOnly
        button.toolTip = toolTip
        button.setAccessibilityLabel(accessibilityLabel)
    }
}
