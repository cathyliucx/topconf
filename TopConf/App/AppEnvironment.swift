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

    static func current(
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> AppLaunchConfiguration {
        AppLaunchConfiguration(
            isUITesting: arguments.contains("-UITesting") || environment["TOPCONF_UI_TESTING"] == "1",
            seedScenario: seedScenario(from: arguments),
            initialSearchQuery: value(after: "-InitialSearchQuery", in: arguments)
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
}
