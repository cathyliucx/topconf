import SwiftUI

struct ConferenceManagementView: View {
    @ObservedObject var viewModel: ConferenceManagementViewModel
    var searchFocusRequest = 0
    var onDone: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            ConferenceFilterBar(viewModel: viewModel, searchFocusRequest: searchFocusRequest)

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Available Conferences")
                            .font(.headline)
                        Spacer()
                        Text(viewModel.discoveryCountText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                            .accessibilityIdentifier("topconf.discovery.count")
                            .accessibilityLabel(viewModel.discoveryCountText)
                    }
                    ConferenceDiscoveryListView(viewModel: viewModel)
                }
                .frame(minWidth: 480)

                TrackedSelectionView(viewModel: viewModel)
                    .frame(minWidth: 320)
            }
        }
        .padding(18)
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
        HStack {
            Text("TopConf")
                .font(.title2)
                .fontWeight(.semibold)
            Spacer()
            if let onDone {
                Button("Done", action: onDone)
                    .accessibilityIdentifier("topconf.management.done")
            }
            Text(viewModel.trackingCountText)
                .monospacedDigit()
                .accessibilityIdentifier("topconf.management.count")
        }
    }
}

struct ConferenceRowSummary: View {
    let conference: ConferenceRowPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Text(conference.abbreviation)
                    .font(.headline)
                Text(rankText(conference.rank))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(conference.fullName)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(conference.categoryName)
                .font(.caption)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }

    private func rankText(_ rank: CCFRank) -> String {
        switch rank {
        case .a:
            return "CCF-A"
        case .b:
            return "CCF-B"
        case .c:
            return "CCF-C"
        case .unranked:
            return "Unranked"
        case .unknown:
            return "Unknown"
        }
    }
}
