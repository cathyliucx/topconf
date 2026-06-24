import Foundation

final class LauncherPanelState: ObservableObject {
    @Published private(set) var searchFocusRequest = 0

    func requestSearchFocus() {
        searchFocusRequest += 1
    }
}
