import SwiftUI

struct ConferenceDiscoveryListView: View {
    @ObservedObject var viewModel: ConferenceManagementViewModel

    var body: some View {
        List(viewModel.discoveredConferences) { conference in
            HStack(spacing: 12) {
                ConferenceRowSummary(conference: conference)
                Spacer()
                if conference.isTracked {
                    Button("Remove") {
                        Task { await viewModel.removeConference(id: conference.id) }
                    }
                    .accessibilityIdentifier("topconf.discovery.remove.\(conference.id)")
                } else {
                    Button("Add") {
                        Task { await viewModel.addConference(id: conference.id) }
                    }
                    .disabled(!conference.canAdd)
                    .accessibilityIdentifier("topconf.add.\(conference.id)")
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("topconf.row.\(conference.id)")
        }
        .accessibilityIdentifier("topconf.management.available")
    }
}
