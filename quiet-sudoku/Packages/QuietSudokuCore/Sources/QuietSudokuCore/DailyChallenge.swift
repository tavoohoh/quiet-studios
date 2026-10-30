import QuietCore

/// Today's puzzle: the same for everyone on a day key, built on device.
public enum DailyChallenge {
    public static func difficulty(forDayKey key: String) -> Difficulty {
        DailyKey.weekday(ofDayKey: key).map(Difficulty.forWeekday) ?? .medium
    }

    /// Tries `"<day>#0"`, `"<day>#1"`… (FNV-1a → `SeededRandom`) and keeps the first puzzle
    /// with the day's level. About 0.2 s for an expert day in release on a Mac (2026-10-30);
    /// run it off the main thread.
    public static func puzzle(forDayKey key: String) -> Puzzle {
        Generator.puzzle(key: key, difficulty: difficulty(forDayKey: key))
    }

    public static func session(forDayKey key: String, scoring: Scoring = .standard) -> GameSession {
        GameSession(mode: .daily(dayKey: key), puzzle: puzzle(forDayKey: key), scoring: scoring)
    }
}
