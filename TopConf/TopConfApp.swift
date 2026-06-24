import SwiftUI

@main
struct TopConfApp: App {
    private let containerResult: Result<DependencyContainer, Error>

    init() {
        containerResult = Result {
            try DependencyContainer.make()
        }
    }

    var body: some Scene {
        WindowGroup {
            switch containerResult {
            case let .success(container):
                AppRootView(container: container)
            case let .failure(error):
                EmptyStateView(
                    title: "TopConf could not start",
                    message: error.localizedDescription
                )
                .frame(minWidth: 420, minHeight: 240)
                .accessibilityIdentifier("topconf.error")
            }
        }
    }
}
