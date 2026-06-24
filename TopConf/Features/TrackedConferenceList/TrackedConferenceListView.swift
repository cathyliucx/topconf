import SwiftUI

struct TrackedConferenceListView: View {
    @ObservedObject var viewModel: TrackedConferenceListViewModel
    let onManage: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            content
        }
        .padding(18)
        .task {
            await viewModel.load()
        }
        .overlay(alignment: .bottom) {
            if let error = viewModel.presentationError {
                Text(error.message)
                    .padding(10)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityIdentifier("topconf.error")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TopConf")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("\(viewModel.trackingCountText) · \(viewModel.lastUpdatedText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Spacer()
                Button("Manage Conferences", action: onManage)
                    .accessibilityIdentifier("topconf.tracked.manage")
            }

            HStack {
                TextField("Search tracked conferences", text: $viewModel.searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("topconf.search.tracked")
                    .onChange(of: viewModel.searchQuery) { _, _ in
                        viewModel.refreshSearch()
                    }
                    .onSubmit {
                        viewModel.refreshSearch()
                    }

                if !viewModel.searchQuery.isEmpty {
                    Button("Clear", action: viewModel.clearSearch)
                        .accessibilityIdentifier("topconf.search.tracked.clear")
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.loadState {
        case .idle, .loading:
            LoadingIndicator(text: "Loading tracked conferences")
                .accessibilityIdentifier("topconf.loading")
        case .loaded where viewModel.rows.isEmpty:
            VStack(spacing: 12) {
                EmptyStateView(
                    title: "No conferences are being tracked.",
                    message: "Browse the complete catalog from the four supported categories and track any subset of at most 10 conferences."
                )
                Button("Choose Conferences", action: onManage)
                    .accessibilityIdentifier("topconf.tracked.manage")
            }
            .accessibilityIdentifier("topconf.empty.noTracked")
        case .loaded:
            if viewModel.visibleRows.isEmpty {
                EmptyStateView(
                    title: "No tracked conferences match your search.",
                    message: "Clear the search to return to all tracked conferences."
                )
            } else {
                TrackedConferenceTableView(rows: viewModel.visibleRows)
            }
        case .failed:
            VStack(spacing: 12) {
                EmptyStateView(
                    title: "Tracked conferences could not be loaded.",
                    message: "Check the local data store and try again."
                )
                Button("Retry") {
                    Task { await viewModel.retry() }
                }
                .accessibilityIdentifier("topconf.tracked.retry")
            }
            .accessibilityIdentifier("topconf.error")
        }
    }
}
