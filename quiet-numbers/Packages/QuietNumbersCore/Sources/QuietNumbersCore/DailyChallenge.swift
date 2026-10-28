import QuietCore

/// The daily board: the same board for every player on a given day key, generated on device.
/// Day keys, rollover, replay window and streaks come from `DailyKey` and `Streaks` (QuietCore).
public enum DailyChallenge {
    /// The day's score to reach, 400–700 in steps of 50. Drawn from its own stream of the
    /// day's seed, so it doesn't change the boards.
    public static let goals = Array(stride(from: 400, through: 700, by: 50))

    public static func goal(forDayKey key: String) -> Int {
        var random = SeededRandom(seed: DailyKey.seed(forDayKey: key) ^ 0x60A1_5C0E)
        return goals[random.nextInt(in: 0...(goals.count - 1))]
    }

    /// Every player gets the same boards: later stages come from the same seeded generator,
    /// which only advances when a board is generated, never with moves.
    public static func session(forDayKey key: String, scoring: Scoring = .standard) -> GameSession {
        GameSession(mode: .daily(dayKey: key), seed: DailyKey.seed(forDayKey: key), scoring: scoring, goal: goal(forDayKey: key))
    }
}
