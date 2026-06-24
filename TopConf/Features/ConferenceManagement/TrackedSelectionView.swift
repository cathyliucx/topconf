import SwiftUI

struct TrackedSelectionView: View {
    @ObservedObject var viewModel: ConferenceManagementViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("My Conferences")
                    .font(.headline)
                Spacer()
                Text(viewModel.trackingCountText)
                    .monospacedDigit()
                    .accessibilityIdentifier("topconf.management.count")
            }

            if viewModel.trackedConferences.isEmpty {
                EmptyStateView(
                    title: "No conferences selected",
                    message: "Choose up to 10 conferences to track."
                )
                .accessibilityIdentifier("topconf.empty.noTracked")
            } else {
                List(viewModel.trackedConferences) { conference in
                    HStack(spacing: 12) {
                        ConferenceRowSummary(conference: conference)
                        Spacer()
                        Button("Remove") {
                            Task { await viewModel.removeConference(id: conference.id) }
                        }
                        .accessibilityIdentifier("topconf.tracked.remove.\(conference.id)")
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("topconf.row.\(conference.id)")
                }
                .accessibilityIdentifier("topconf.management.tracked")
            }
        }
        .accessibilityIdentifier("topconf.management.tracked")
    }
}
