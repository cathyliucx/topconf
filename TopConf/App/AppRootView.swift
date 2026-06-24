import SwiftUI

struct AppRootView: View {
    @StateObject private var managementViewModel: ConferenceManagementViewModel
    @StateObject private var trackedListViewModel: TrackedConferenceListViewModel
    @State private var route: AppRoute = .loading
    private let container: DependencyContainer

    init(container: DependencyContainer) {
        self.container = container
        _managementViewModel = StateObject(wrappedValue: container.makeConferenceManagementViewModel())
        _trackedListViewModel = StateObject(wrappedValue: container.makeTrackedConferenceListViewModel())
    }

    var body: some View {
        Group {
            switch route {
            case .loading:
                LoadingIndicator(text: "Loading conferences")
                    .accessibilityIdentifier("topconf.loading")
            case .trackedList:
                TrackedConferenceListView(viewModel: trackedListViewModel) {
                    route = .management
                }
            case .onboarding:
                OnboardingView(viewModel: managementViewModel) {
                    route = .trackedList
                }
            case .management:
                ConferenceManagementView(viewModel: managementViewModel) {
                    Task {
                        await trackedListViewModel.load()
                        route = routeAfterTrackedLoad()
                    }
                }
                    .toolbar {
                        Button("Done") {
                            Task {
                                await trackedListViewModel.load()
                                route = routeAfterTrackedLoad()
                            }
                        }
                    }
            case let .failed(message):
                EmptyStateView(title: "TopConf could not start", message: message)
                    .accessibilityIdentifier("topconf.error")
            }
        }
        .task {
            await start()
        }
        .frame(minWidth: 900, minHeight: 560)
    }

    private func start() async {
        do {
            try await container.seedIfNeeded()
            await managementViewModel.load()
            if let initialSearchQuery = container.configuration.initialSearchQuery {
                managementViewModel.searchQuery = initialSearchQuery
                managementViewModel.refreshFilters()
            }
            await trackedListViewModel.load()
            route = routeAfterTrackedLoad()
        } catch {
            route = .failed(error.localizedDescription)
        }
    }

    private func routeAfterTrackedLoad() -> AppRoute {
        if trackedListViewModel.rows.isEmpty && container.configuration.seedScenario != .zeroTracked {
            return .onboarding
        }
        return .trackedList
    }
}

private enum AppRoute: Equatable {
    case loading
    case trackedList
    case onboarding
    case management
    case failed(String)
}
