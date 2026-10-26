import Foundation

/// The daily board: same for every player on a given UTC day, generated on device.
public enum DailyChallenge {
    /// Past days that can still be replayed (unscored).
    public static let replayWindow = 30

    /// `yyyy-MM-dd` in UTC. The challenge rolls over at 00:00 UTC.
    public static func dayKey(for date: Date) -> String {
        let parts = utcCalendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    /// Midnight UTC of a `yyyy-MM-dd` key, or `nil` if the key is malformed.
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
        return dayKey(for: moved)
    }

    public static func seed(forDayKey key: String) -> UInt64 {
        FNV1a.hash(key)
    }

    public static func seed(for date: Date) -> UInt64 {
        seed(forDayKey: dayKey(for: date))
    }

    public static func session(forDayKey key: String) -> GameSession {
        GameSession(mode: .daily(dayKey: key), seed: seed(forDayKey: key))
    }

    public static func session(for date: Date) -> GameSession {
        session(forDayKey: dayKey(for: date))
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
        var day = completed.contains(today) ? today : DailyChallenge.dayKey(today, addingDays: -1)
        var count = 0
        while let key = day, completed.contains(key) {
            count += 1
            day = DailyChallenge.dayKey(key, addingDays: -1)
        }
        return count
    }

    public static func longest(completed: Set<String>) -> Int {
        var longest = 0
        for key in completed {
            // Only start counting at the first day of a run.
            if let previous = DailyChallenge.dayKey(key, addingDays: -1), completed.contains(previous) { continue }
            var length = 0
            var day: String? = key
            while let current = day, completed.contains(current) {
                length += 1
                day = DailyChallenge.dayKey(current, addingDays: 1)
            }
            longest = max(longest, length)
        }
        return longest
    }
}
