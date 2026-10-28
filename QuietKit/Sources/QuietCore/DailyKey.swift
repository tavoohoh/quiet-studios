import Foundation

/// Daily challenges: the same content for every player on a given day key, built on device.
/// Each app turns `seed(forDayKey:)` into its own board or deal.
public enum DailyKey {
    /// Past days that can still be replayed (unscored).
    public static let replayWindow = 30
    /// Local hour when the next day's challenge starts: midnight, like Quiet Numbers since
    /// 2026-10-27 (it was 19:00), so the day's challenge can be played at any hour.
    public static let rolloverHour = 0

    /// `yyyy-MM-dd` of the challenge on at `date`: the device's local day, moved to the
    /// next one from `rolloverHour` on (no shift at midnight).
    public static func dayKey(for date: Date, timeZone: TimeZone = .current) -> String {
        let calendar = localCalendar(timeZone)
        var day = calendar.startOfDay(for: date)
        if rolloverHour > 0, calendar.component(.hour, from: date) >= rolloverHour {
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        let parts = calendar.dateComponents([.year, .month, .day], from: day)
        return key(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    /// When the challenge after the one on at `date` starts.
    public static func nextRollover(after date: Date, timeZone: TimeZone = .current) -> Date {
        let calendar = localCalendar(timeZone)
        let today = calendar.date(bySettingHour: rolloverHour, minute: 0, second: 0, of: date)!
        return today > date ? today : calendar.date(byAdding: .day, value: 1, to: today)!
    }

    /// Midnight UTC of a `yyyy-MM-dd` key, or `nil` if the key is malformed.
    /// Only a label for the day (formatting, arithmetic), not when it starts.
    public static func date(forDayKey key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return utcCalendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// The key `days` days after (or before, if negative) `key`.
    public static func dayKey(_ key: String, addingDays days: Int) -> String? {
        guard let date = date(forDayKey: key),
              let moved = utcCalendar.date(byAdding: .day, value: days, to: date)
        else { return nil }
        let parts = utcCalendar.dateComponents([.year, .month, .day], from: moved)
        return Self.key(year: parts.year!, month: parts.month!, day: parts.day!)
    }

    /// 1 = Monday … 7 = Sunday, for the key's calendar day (independent of the device locale).
    public static func weekday(ofDayKey key: String) -> Int? {
        guard let date = date(forDayKey: key) else { return nil }
        let sundayFirst = utcCalendar.component(.weekday, from: date)
        return (sundayFirst + 5) % 7 + 1
    }

    public static func seed(forDayKey key: String) -> UInt64 {
        FNV1a.hash(key)
    }

    private static func key(year: Int, month: Int, day: Int) -> String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func localCalendar(_ timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
}

/// Consecutive completed daily challenges.
public enum Streaks {
    /// Streak still alive on `today`: it ends today, or yesterday if today isn't done yet.
    public static func current(completed: Set<String>, today: String) -> Int {
        var day = completed.contains(today) ? today : DailyKey.dayKey(today, addingDays: -1)
        var count = 0
        while let key = day, completed.contains(key) {
            count += 1
            day = DailyKey.dayKey(key, addingDays: -1)
        }
        return count
    }

    public static func longest(completed: Set<String>) -> Int {
        var longest = 0
        for key in completed {
            // Only start counting at the first day of a run.
            if let previous = DailyKey.dayKey(key, addingDays: -1), completed.contains(previous) { continue }
            var length = 0
            var day: String? = key
            while let current = day, completed.contains(current) {
                length += 1
                day = DailyKey.dayKey(current, addingDays: 1)
            }
            longest = max(longest, length)
        }
        return longest
    }
}
