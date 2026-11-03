/// Achievements. Each one unlocks a cosmetic reward; only "In the Red" touches play
/// (cheaper hints in classic games).
public enum Achievement: String, CaseIterable, Codable, Sendable {
    /// Solve a first puzzle.
    case firstWin
    /// Solve without mistakes.
    case noMistakes
    /// Solve without hints.
    case noHints
    /// Solve a medium or harder puzzle without notes.
    case noNotes
    case tenWins
    /// 7-day daily streak.
    case consistency
    /// 30-day daily streak.
    case habit
    /// Solve an expert puzzle.
    case expert
    /// Solve an easy puzzle in under 4 minutes.
    case quick
    /// Solve a daily between 00:00 and 04:00 local time.
    case nightOwl
    /// Solve 100 puzzles.
    case centennial
    /// Take the score below zero. Hidden.
    case inTheRed

    /// Amount needed for counted achievements; 1 for one-off ones.
    public var target: Int {
        switch self {
        case .tenWins: 10
        case .consistency: 7
        case .habit: 30
        case .centennial: 100
        default: 1
        }
    }

    /// Hidden in Game Center until earned. Only the easter egg.
    public var isHidden: Bool { self == .inTheRed }

    /// "Quick" needs an easy puzzle in less than this.
    public static let quickSeconds = 240
}

/// Something that happened in play, fed to `PlayerProgress`.
public enum ProgressEvent: Sendable {
    case won(WinSummary, isClassic: Bool)
    /// The score after a mistake or a hint (for "In the Red").
    case scoreChanged(Int)
    /// A classic game was replaced before it ended; it counts as played if anything was played.
    case abandoned(played: Bool)
    /// A day's challenge was won for the first time (today's, or a past day that fills the
    /// streak). Replays of a day already won don't send it.
    case dailyCompleted(currentStreak: Int, localHour: Int)
    /// A past day won for the first time after its date: the calendar tints it apart (the
    /// app also sends `dailyCompleted`).
    case completedLate(dayKey: String)
}

/// Lifetime counters and unlocked achievements. Stored locally; works without Game Center.
public struct PlayerProgress: Codable, Hashable, Sendable {
    public private(set) var unlocked: Set<Achievement> = []
    public private(set) var gamesWon = 0
    public private(set) var gamesPlayed = 0
    public private(set) var dailiesCompleted = 0
    public private(set) var bestStreak = 0
    /// Best classic score.
    public private(set) var bestScore = 0
    /// Past days first won after their date.
    public private(set) var lateDays: Set<String> = []
    /// Fastest solve per level, in seconds (keyed by `Difficulty.rawValue`).
    public private(set) var bestTimes: [Int: Int] = [:]

    public init() {}

    /// `lateDays` keeps the key it had when replays were called "practice" (before 2026-11-02).
    private enum CodingKeys: String, CodingKey {
        case unlocked, gamesWon, gamesPlayed, dailiesCompleted, bestStreak, bestScore, bestTimes
        case lateDays = "practicedDays"
    }

    /// Starts with achievements already unlocked (QA and screenshots).
    public init(unlocked: Set<Achievement>) {
        self.unlocked = unlocked
    }

    public func bestTime(_ difficulty: Difficulty) -> Int? { bestTimes[difficulty.rawValue] }

    /// Share of games played that were solved, 0...1.
    public var winRate: Double { gamesPlayed == 0 ? 0 : Double(gamesWon) / Double(gamesPlayed) }

    /// Applies an event and returns achievements unlocked by it.
    public mutating func record(_ event: ProgressEvent) -> [Achievement] {
        var hits: [Achievement] = []
        switch event {
        case .won(let summary, let isClassic):
            gamesWon += 1
            gamesPlayed += 1
            hits.append(.firstWin)
            if summary.mistakes == 0 { hits.append(.noMistakes) }
            if summary.hintsUsed == 0 { hits.append(.noHints) }
            if !summary.usedNotes, summary.difficulty >= .medium { hits.append(.noNotes) }
            if summary.difficulty == .expert { hits.append(.expert) }
            if summary.difficulty == .easy, summary.seconds < Achievement.quickSeconds { hits.append(.quick) }
            if isClassic { bestScore = max(bestScore, summary.score) }
            let key = summary.difficulty.rawValue
            bestTimes[key] = min(bestTimes[key] ?? .max, summary.seconds)
        case .scoreChanged(let score):
            if score < 0 { hits.append(.inTheRed) }
        case .abandoned(let played):
            if played { gamesPlayed += 1 }
        case .dailyCompleted(let streak, let hour):
            dailiesCompleted += 1
            bestStreak = max(bestStreak, streak)
            if (0..<4).contains(hour) { hits.append(.nightOwl) }
        case .completedLate(let dayKey):
            lateDays.insert(dayKey)
        }
        hits += Achievement.allCases.filter { $0.target > 1 && count(for: $0) >= $0.target }
        return unlock(hits)
    }

    /// Combines progress from two devices: every counter keeps its highest value (fastest
    /// time) and achievements are the union, so nothing earned is ever lost.
    public func merged(with other: PlayerProgress) -> PlayerProgress {
        var result = self
        result.unlocked.formUnion(other.unlocked)
        result.gamesWon = max(gamesWon, other.gamesWon)
        result.gamesPlayed = max(gamesPlayed, other.gamesPlayed)
        result.dailiesCompleted = max(dailiesCompleted, other.dailiesCompleted)
        result.bestStreak = max(bestStreak, other.bestStreak)
        result.bestScore = max(bestScore, other.bestScore)
        result.lateDays.formUnion(other.lateDays)
        result.bestTimes.merge(other.bestTimes) { min($0, $1) }
        return result
    }

    /// Progress towards an achievement, 0...1 (for Game Center's percentage).
    public func progress(of achievement: Achievement) -> Double {
        if unlocked.contains(achievement) { return 1 }
        return min(Double(count(for: achievement)) / Double(achievement.target), 1)
    }

    private func count(for achievement: Achievement) -> Int {
        switch achievement {
        case .tenWins, .centennial: gamesWon
        case .consistency, .habit: bestStreak
        default: 0
        }
    }

    private mutating func unlock(_ candidates: [Achievement]) -> [Achievement] {
        var new: [Achievement] = []
        for achievement in candidates where unlocked.insert(achievement).inserted {
            new.append(achievement)
        }
        return new
    }
}
