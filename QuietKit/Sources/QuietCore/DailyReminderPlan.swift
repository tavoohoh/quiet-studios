import Foundation

/// Which daily-challenge notifications to schedule (pure, so it's tested here; QuietUI's
/// `DailyReminders` hands the plan to the system). At most two a day:
/// - the reminder at `reminderHour` on a day not completed yet;
/// - "streak at risk" at `streakHour`, when a streak of `minimumStreak` or more would end
///   that night.
///
/// Only the next day that can still be completed knows its streak at stake: today if it's
/// not done, otherwise tomorrow. Later days get the plain reminder; the app plans again
/// each time it opens, at midnight and when the time zone changes.
public enum DailyReminderPlan {
    public enum Kind: String, Sendable, CaseIterable {
        case reminder
        case streakAtRisk
    }

    public struct Item: Equatable, Sendable {
        public let kind: Kind
        public let dayKey: String
        /// Local wall-clock time it fires (year, month, day, hour).
        public let components: DateComponents
        /// The streak that ends at midnight if the day isn't completed (0: none at stake).
        public let streak: Int

        /// Stable per day and kind, so planning again replaces instead of duplicating.
        public var identifier: String { "daily.\(dayKey).\(kind.rawValue)" }
    }

    public static let reminderHour = 19
    public static let streakHour = 21
    public static let minimumStreak = 3
    /// Days planned ahead, in case the app isn't opened for a while.
    public static let daysAhead = 7

    /// `streak`: the current streak (`Streaks.current`), which counts today once it's done.
    public static func items(
        now: Date, todayCompleted: Bool, streak: Int, timeZone: TimeZone = .current,
        days: Int = daysAhead, reminderHour: Int = reminderHour, streakHour: Int = streakHour,
        minimumStreak: Int = minimumStreak
    ) -> [Item] {
        let today = DailyKey.dayKey(for: now, timeZone: timeZone)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var items: [Item] = []
        let first = todayCompleted ? 1 : 0
        for offset in first..<days {
            guard let day = DailyKey.dayKey(today, addingDays: offset) else { continue }
            // Missing the first day breaks the streak, so later days have none at stake.
            let atStake = offset == first ? streak : 0
            let parts = day.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 3 else { continue }
            for (kind, hour) in [(Kind.reminder, reminderHour), (.streakAtRisk, streakHour)] {
                if kind == .streakAtRisk, atStake < minimumStreak { continue }
                let components = DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: hour)
                guard let date = calendar.date(from: components), date > now else { continue }
                items.append(Item(kind: kind, dayKey: day, components: components, streak: atStake < minimumStreak ? 0 : atStake))
            }
        }
        return items
    }
}

/// Today's daily among Game Center friends, for the reminder's text and the "Friends today"
/// card. Built from entries already on screen or loaded in the background; never stored.
public struct FriendsToday: Equatable, Sendable {
    /// Friends (not the player) who already played today.
    public let count: Int
    /// The best of them: name and score.
    public let leaderName: String?
    public let leaderScore: Int?

    public init(count: Int, leaderName: String?, leaderScore: Int?) {
        self.count = count
        self.leaderName = leaderName
        self.leaderScore = leaderScore
    }
}

/// One past daily, head to head: who did better (higher score, then less time).
public enum DailyDuel {
    public enum Result: Equatable, Sendable {
        case won, lost, tied
        /// One of the two didn't play it.
        case notBoth
    }

    /// `seconds` nil: unknown time, which loses a tie on score.
    public static func result(mine: (score: Int, seconds: Int?)?, theirs: (score: Int, seconds: Int?)?) -> Result {
        guard let mine, let theirs else { return .notBoth }
        if mine.score != theirs.score { return mine.score > theirs.score ? .won : .lost }
        let a = mine.seconds ?? .max, b = theirs.seconds ?? .max
        return a == b ? .tied : a < b ? .won : .lost
    }
}
