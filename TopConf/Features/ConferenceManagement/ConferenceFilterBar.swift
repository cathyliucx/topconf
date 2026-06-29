import SwiftUI

struct ConferenceFilterBar: View {
    @ObservedObject var viewModel: ConferenceManagementViewModel
    var searchFocusRequest = 0
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Search conferences", text: $viewModel.searchQuery)
                .textFieldStyle(.roundedBorder)
                .focused($isSearchFocused)
                .accessibilityIdentifier("topconf.search.discovery")
                .onChange(of: viewModel.searchQuery) {
                    viewModel.refreshFilters()
                }

            filterSection(title: "Categories") {
                ForEach(viewModel.categoryOptions) { category in
                    Button(category.title) {
                        viewModel.toggleCategory(category.id)
                    }
                    .buttonStyle(.bordered)
                    .tint(viewModel.selectedCategoryIDs.contains(category.id) ? .accentColor : .secondary)
                    .accessibilityValue(viewModel.selectedCategoryIDs.contains(category.id) ? "Selected" : "Not selected")
                        .accessibilityIdentifier(category.accessibilityIdentifier)
                }
            }

            filterSection(title: "Rank") {
                ForEach(viewModel.rankOptions) { rank in
                    Button(rank.title) {
                        viewModel.toggleRank(rank.id)
                    }
                    .buttonStyle(.bordered)
                    .tint(viewModel.selectedRanks.contains(rank.id) ? .accentColor : .secondary)
                    .accessibilityValue(viewModel.selectedRanks.contains(rank.id) ? "Selected" : "Not selected")
                        .accessibilityIdentifier(rank.accessibilityIdentifier)
                }
            }
        }
    }

    private func filterSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                content()
            }
        }
        .onAppear(perform: focusSearchIfRequested)
        .onChange(of: searchFocusRequest) { _, _ in
            focusSearchIfRequested()
        }
    }

    private func focusSearchIfRequested() {
        guard searchFocusRequest > 0 else {
            return
        }
        isSearchFocused = true
    }

}
