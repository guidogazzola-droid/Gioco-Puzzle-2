import Foundation

/// Calendar-day identity as a stable `yyyy-MM-dd` string.
///
/// Daily content and streaks are keyed on the player's local calendar day, not
/// on elapsed hours, so a player in any time zone gets exactly one daily board
/// per day. Strings rather than `Date` keeps the save file readable and immune
/// to time-zone drift after a device moves.
public enum DayKey {

    public static func key(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    public static func date(from key: String, calendar: Calendar = .current) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        return calendar.date(from: components)
    }

    /// `true` when `later` is exactly the day after `earlier`.
    public static func isConsecutive(_ earlier: String, _ later: String, calendar: Calendar = .current) -> Bool {
        guard let start = date(from: earlier, calendar: calendar),
              let end = date(from: later, calendar: calendar)
        else { return false }
        return calendar.dateComponents([.day], from: start, to: end).day == 1
    }
}
