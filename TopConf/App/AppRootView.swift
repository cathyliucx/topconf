import SwiftUI

struct AppRootView: View {
    @StateObject private var managementViewModel: ConferenceManagementViewModel
    @StateObject private var trackedListViewModel: TrackedConferenceListViewModel
    @State private var route: AppRoute = .loading
    @ObservedObject private var panelState: LauncherPanelState
    private let container: DependencyContainer

    init(container: DependencyContainer, panelState: LauncherPanelState = LauncherPanelState()) {
        self.container = container
        self.panelState = panelState
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
                TrackedConferenceListView(
                    viewModel: trackedListViewModel,
                    searchFocusRequest: panelState.searchFocusRequest
                ) {
                    route = .management
                }
            case .onboarding:
                OnboardingView(
                    viewModel: managementViewModel,
                    searchFocusRequest: panelState.searchFocusRequest
                ) {
                    route = .trackedList
                }
            case .management:
                ConferenceManagementView(
                    viewModel: managementViewModel,
                    searchFocusRequest: panelState.searchFocusRequest
                ) {
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
            await refreshCatalogInBackground()
        } catch {
            route = .failed(error.localizedDescription)
        }
    }

    private func refreshCatalogInBackground() async {
        guard await container.refreshCatalogInBackground() else {
            return
        }
        await managementViewModel.load()
        await trackedListViewModel.load()
        route = routeAfterTrackedLoad()
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
