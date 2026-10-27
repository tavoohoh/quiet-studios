import QuietCore

/// How hard a winnable deal is, from how much searching the solver needed.
public enum Difficulty: Int, CaseIterable, Codable, Sendable, Comparable {
    case easy, medium, hard, expert

    /// Bands of solver effort (positions expanded before the first win). Tuned on 200
    /// deals with the best-first search (2026-10-27): p25 41, p50 49, p75 130, p90 1,939.
    init(effort: Int) {
        switch effort {
        case ..<46: self = .easy
        case ..<131: self = .medium
        case ..<1_940: self = .hard
        default: self = .expert
        }
    }

    /// Monday and Tuesday easy, Wednesday–Friday medium, Saturday hard, Sunday expert.
    public static func forWeekday(_ weekday: Int) -> Difficulty {
        switch weekday {
        case 1, 2: .easy
        case 3, 4, 5: .medium
        case 6: .hard
        default: .expert
        }
    }

    public static func < (a: Self, b: Self) -> Bool { a.rawValue < b.rawValue }
}

/// Seeds that make winnable deals.
public enum Deals {
    /// The budget for checking a new deal. Counted, not timed: same answer on every device.
    public static let budget = 20_000

    /// Today's deal: tries `"<day>#0"`, `"<day>#1"`… and keeps the first the solver wins
    /// with the day's difficulty. After `attempts` it takes the first winnable one.
    public static func dailySeed(forDayKey key: String, attempts: Int = 40) -> UInt64 {
        let wanted = DailyKey.weekday(ofDayKey: key).map(Difficulty.forWeekday) ?? .medium
        var fallback: UInt64?
        for attempt in 0..<attempts {
            let seed = FNV1a.hash("\(key)#\(attempt)")
            guard case .solved(_, let effort) = Solver.solve(.deal(seed: seed), budget: budget) else { continue }
            if Difficulty(effort: effort) == wanted { return seed }
            if fallback == nil { fallback = seed }
        }
        return fallback ?? FNV1a.hash(key)
    }

    public static func dailyDifficulty(forDayKey key: String) -> Difficulty {
        DailyKey.weekday(ofDayKey: key).map(Difficulty.forWeekday) ?? .medium
    }

    /// A winnable classic deal, starting from `seed` and moving on deterministically.
    public static func winnableSeed(startingAt seed: UInt64, attempts: Int = 30) -> UInt64 {
        var random = SeededRandom(seed: seed)
        var candidate = seed
        for _ in 0..<attempts {
            if case .solved = Solver.solve(.deal(seed: candidate), budget: budget) { return candidate }
            candidate = random.next()
        }
        return candidate
    }
}
