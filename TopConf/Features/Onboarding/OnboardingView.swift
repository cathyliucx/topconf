import SwiftUI

struct OnboardingView: View {
    @ObservedObject var viewModel: ConferenceManagementViewModel
    let onContinue: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Choose Conferences")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Select up to 10 conferences to track.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(viewModel.trackingCountText)
                    .monospacedDigit()
                    .accessibilityIdentifier("topconf.management.count")
            }

            ConferenceManagementView(viewModel: viewModel)

            HStack {
                Spacer()
                Button("Continue") {
                    onContinue()
                }
                .disabled(!viewModel.canContinueOnboarding)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("topconf.onboarding.continue")
            }
        }
        .padding(18)
    }
}
