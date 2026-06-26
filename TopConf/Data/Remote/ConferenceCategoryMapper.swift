import Foundation

enum CategoryMappingResult: Equatable {
    case supported(ConferenceCategory)
    case unsupported(rawValue: String, displayName: String)
    case invalid(rawValue: String)
}

struct ConferenceCategoryMapper {
    func mappingResult(for sourceID: String?) -> CategoryMappingResult {
        let normalized = (sourceID ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else {
            return .invalid(rawValue: "")
        }

        switch normalized.uppercased() {
        case "AI":
            return .supported(SeedConferenceCatalog.ai)
        case "CG":
            return .supported(SeedConferenceCatalog.graphics)
        case "HI", "HCI":
            return .supported(SeedConferenceCatalog.hci)
        case "MX":
            return .supported(SeedConferenceCatalog.interdisciplinary)
        case "DB":
            return .unsupported(
                rawValue: normalized,
                displayName: "Database / Data Mining / Information Retrieval"
            )
        default:
            return .unsupported(rawValue: normalized, displayName: normalized)
        }
    }

    func category(for sourceID: String?) -> ConferenceCategory {
        switch mappingResult(for: sourceID) {
        case let .supported(category):
            return category
        case let .unsupported(rawValue, displayName):
            return ConferenceCategory(sourceID: rawValue, displayName: displayName)
        case let .invalid(rawValue):
            return ConferenceCategory(sourceID: rawValue.isEmpty ? "unknown" : rawValue, displayName: "Unknown")
        }
    }
}
