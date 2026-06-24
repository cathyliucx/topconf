import SwiftUI

@main
struct TopConfApp: App {
    @NSApplicationDelegateAdaptor(TopConfAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
