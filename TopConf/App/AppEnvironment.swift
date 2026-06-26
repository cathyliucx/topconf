import Foundation

enum SeedScenario: String, Equatable {
    case none
    case empty
    case nineTracked
    case tenTracked
    case zeroTracked
    case oneUpcoming
    case multipleSorted
    case tbdAndClosed
    case sourceUnavailable
}

struct AppLaunchConfiguration: Equatable {
    let isUITesting: Bool
    let seedScenario: SeedScenario
    let initialSearchQuery: String?
    let appearanceOverride: AppAppearanceOverride?

    init(
        isUITesting: Bool,
        seedScenario: SeedScenario,
        initialSearchQuery: String?,
        appearanceOverride: AppAppearanceOverride? = nil
    ) {
        self.isUITesting = isUITesting
        self.seedScenario = seedScenario
        self.initialSearchQuery = initialSearchQuery
        self.appearanceOverride = appearanceOverride
    }

    static func current(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> AppLaunchConfiguration {
        let isUITesting = arguments.contains("-UITesting") || environment["TOPCONF_UI_TESTING"] == "1"
        return AppLaunchConfiguration(
            isUITesting: isUITesting,
            seedScenario: seedScenario(from: arguments),
            initialSearchQuery: value(after: "-InitialSearchQuery", in: arguments),
            appearanceOverride: isUITesting ? appearanceOverride(from: arguments) : nil
        )
    }

    private static func seedScenario(from arguments: [String]) -> SeedScenario {
        guard let rawValue = value(after: "-SeedScenario", in: arguments) else {
            return .none
        }
        return SeedScenario(rawValue: rawValue) ?? .none
    }

    private static func value(after flag: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(arguments.index(after: index)) else {
            return nil
        }
        return arguments[arguments.index(after: index)]
    }

    private static func appearanceOverride(from arguments: [String]) -> AppAppearanceOverride? {
        guard let rawValue = value(after: "-Appearance", in: arguments) else {
            return nil
        }
        return AppAppearanceOverride(rawValue: rawValue)
    }
}

enum AppAppearanceOverride: String, Equatable {
    case light
    case dark
}
