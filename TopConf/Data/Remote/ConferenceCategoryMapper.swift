import Foundation

struct ConferenceCategoryMapper {
    func category(for sourceID: String?) -> ConferenceCategory {
        let normalized = (sourceID ?? "unknown").trimmingCharacters(in: .whitespacesAndNewlines)
        let key = normalized.uppercased()
        let displayName: String
        switch key {
        case "AI":
            displayName = "Artificial Intelligence"
        case "CG":
            displayName = "Computer Graphics and Multimedia"
        case "HI", "HCI":
            displayName = "Human-Computer Interaction and Ubiquitous Computing"
        case "MX":
            displayName = "Interdisciplinary, Comprehensive, and Emerging Areas"
        default:
            displayName = normalized.isEmpty ? "Unknown" : normalized
        }
        return ConferenceCategory(sourceID: normalized.isEmpty ? "unknown" : normalized, displayName: displayName)
    }
}
