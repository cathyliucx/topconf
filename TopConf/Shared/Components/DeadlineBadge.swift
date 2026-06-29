import SwiftUI

struct DeadlineBadge: View {
    let text: String
    let status: DeadlineStatus

    var body: some View {
        Text(text)
            .font(.caption)
            .fontWeight(status == .closingSoon ? .semibold : .regular)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .foregroundStyle(foregroundStyle)
            .background(backgroundStyle)
            .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    private var foregroundStyle: Color {
        switch status {
        case .upcoming:
            return .primary
        case .closingSoon:
            return .orange
        case .closed, .toBeDetermined:
            return .secondary
        }
    }

    private var backgroundStyle: Color {
        switch status {
        case .closingSoon:
            return .orange.opacity(0.12)
        case .upcoming:
            return .secondary.opacity(0.08)
        case .closed, .toBeDetermined:
            return .secondary.opacity(0.06)
        }
    }
}
