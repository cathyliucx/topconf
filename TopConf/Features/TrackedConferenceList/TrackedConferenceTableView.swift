import SwiftUI

struct TrackedConferenceTableView: View {
    let rows: [TrackedConferenceRowPresentation]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider()
                ForEach(rows) { row in
                    TrackedConferenceRowView(row: row)
                    Divider()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(.background)
        .accessibilityIdentifier("topconf.tracked.table")
    }

    private var header: some View {
        HStack(spacing: 14) {
            Text("State")
                .frame(width: 58, alignment: .leading)
            Text("Conference")
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Remaining")
                .frame(width: 100, alignment: .leading)
            Text("Original deadline")
                .frame(width: 190, alignment: .leading)
            Text("Beijing")
                .frame(width: 150, alignment: .leading)
            Text("Actions")
                .frame(width: 70, alignment: .leading)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.vertical, 4)
    }
}
