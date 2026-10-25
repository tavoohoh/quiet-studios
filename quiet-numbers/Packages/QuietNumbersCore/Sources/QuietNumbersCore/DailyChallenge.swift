import Foundation

/// The daily board: same for every player on a given UTC day, generated on device.
public enum DailyChallenge {
    /// `yyyy-MM-dd` in UTC. The challenge rolls over at 00:00 UTC.
    public static func dayKey(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    public static func seed(for date: Date) -> UInt64 {
        FNV1a.hash(dayKey(for: date))
    }

    public static func session(for date: Date) -> GameSession {
        GameSession(mode: .daily(dayKey: dayKey(for: date)), seed: seed(for: date))
    }
}
