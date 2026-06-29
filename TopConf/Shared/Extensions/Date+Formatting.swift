import Foundation

enum TopConfDateFormatting {
    static let beijingTimeZoneIdentifier = "Asia/Shanghai"
    static let beijingCompactLabel = "Beijing"
    static let fixedLocale = Locale(identifier: "en_US_POSIX")

    static func compactDateTime(
        _ date: Date,
        timeZone: TimeZone,
        includeYear: Bool = false
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = fixedLocale
        formatter.timeZone = timeZone
        formatter.dateFormat = includeYear ? "MMM d, yyyy, HH:mm" : "MMM d, HH:mm"
        return formatter.string(from: date)
    }

    static func beijingTime(_ date: Date) -> String {
        guard let timeZone = TimeZone(identifier: beijingTimeZoneIdentifier) else {
            return compactDateTime(date, timeZone: TimeZone(secondsFromGMT: 8 * 60 * 60) ?? .current)
        }
        return "\(compactDateTime(date, timeZone: timeZone)) \(beijingCompactLabel)"
    }
}
