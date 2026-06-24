import SwiftUI

struct TrackedConferenceRowView: View {
    let row: TrackedConferenceRowPresentation

    var body: some View {
        HStack(spacing: 14) {
            Text(row.trackedStateText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 58, alignment: .leading)

            conferenceColumn

            DeadlineBadge(text: row.deadline.remainingText, status: row.deadline.status)
                .monospacedDigit()
                .frame(width: 100, alignment: .leading)
                .accessibilityIdentifier("topconf.tracked.remaining.\(row.id)")

            Text(row.deadline.originalDeadlineText)
                .font(.callout)
                .monospacedDigit()
                .lineLimit(1)
                .foregroundStyle(row.availability == .sourceUnavailable ? .secondary : .primary)
                .frame(width: 190, alignment: .leading)
                .accessibilityIdentifier("topconf.tracked.originalDeadline.\(row.id)")

            Text(row.deadline.beijingTimeText)
                .font(.callout)
                .monospacedDigit()
                .lineLimit(1)
                .foregroundStyle(.secondary)
                .frame(width: 150, alignment: .leading)
                .accessibilityIdentifier("topconf.tracked.beijingTime.\(row.id)")

            actions
                .frame(width: 70, alignment: .leading)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("topconf.tracked.row.\(row.id)")
    }

    private var conferenceColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(row.abbreviation)
                    .font(.headline)
                    .accessibilityIdentifier("topconf.tracked.abbreviation.\(row.id)")
                if row.editionYearText != "-" {
                    Text(row.editionYearText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(row.fullName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text("\(row.deadline.typeText) · \(row.deadline.statusText)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .accessibilityIdentifier("topconf.tracked.status.\(row.id)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var actions: some View {
        if let url = row.websiteURL {
            Link("Website", destination: url)
                .accessibilityIdentifier("topconf.tracked.website.\(row.id)")
        } else {
            Text("-")
                .foregroundStyle(.tertiary)
        }
    }
}
