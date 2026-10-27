/// Achievements. Each one unlocks a cosmetic reward; only "In the Red" touches play
/// (cheaper hints outside the scored daily).
public enum Achievement: String, CaseIterable, Codable, Sendable {
    /// Win a first game.
    case firstWin
    /// Win without undo.
    case noUndo
    /// Win without hints.
    case noHints
    /// Win without recycling the stock.
    case onePass
    case tenWins
    /// 7-day daily streak.
    case consistency
    /// 30-day daily streak.
    case habit
    /// A king-to-ace run in one tableau column.
    case ladder
    /// Win 100 games.
    case centennial
    /// Win a daily between 00:00 and 04:00 local time. Hidden.
    case nightOwl
    case fiftyWins
    /// Win in fewer than 100 moves. Hidden.
    case economy
    /// Take the score below zero. Hidden.
    case inTheRed

    /// Amount needed for counted achievements; 1 for one-off ones.
    public var target: Int {
        switch self {
        case .tenWins: 10
        case .consistency: 7
        case .habit: 30
        case .centennial: 100
        case .fiftyWins: 50
        default: 1
        }
    }

    public var isHidden: Bool { self == .nightOwl || self == .economy || self == .inTheRed }
}

/// Something that happened in play, fed to `PlayerProgress`.
public enum ProgressEvent: Sendable {
    case won(WinSummary, isClassic: Bool)
    case hintCharged(scoreAfter: Int)
    case ladder
    /// A classic game was replaced before it ended; it counts as played if anything was played.
    case abandoned(played: Bool)
    /// The classic game on screen reached this score: the best updates right away.
    case classicScore(Int)
    /// Today's daily was won on its own day.
    case dailyCompleted(currentStreak: Int, localHour: Int)
    /// A past day won as practice: shown on the calendar, nothing else.
    case practiceCompleted(dayKey: String)
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
    /// Past days won as practice.
    public private(set) var practicedDays: Set<String> = []

    public init() {}

    /// Starts with achievements already unlocked (QA and screenshots).
    public init(unlocked: Set<Achievement>) {
        self.unlocked = unlocked
    }

    /// Share of games played that were won, 0...1.
    public var winRate: Double { gamesPlayed == 0 ? 0 : Double(gamesWon) / Double(gamesPlayed) }

    /// Applies an event and returns achievements unlocked by it.
    public mutating func record(_ event: ProgressEvent) -> [Achievement] {
        var hits: [Achievement] = []
        switch event {
        case .won(let summary, let isClassic):
            gamesWon += 1
            gamesPlayed += 1
            hits.append(.firstWin)
            if !summary.usedUndo { hits.append(.noUndo) }
            if summary.hintsUsed == 0 { hits.append(.noHints) }
            if summary.recycles == 0 { hits.append(.onePass) }
            if summary.moves < 100 { hits.append(.economy) }
            if isClassic { bestScore = max(bestScore, summary.score) }
        case .hintCharged(let score):
            if score < 0 { hits.append(.inTheRed) }
        case .ladder:
            hits.append(.ladder)
        case .abandoned(let played):
            if played { gamesPlayed += 1 }
        case .classicScore(let score):
            bestScore = max(bestScore, score)
        case .dailyCompleted(let streak, let hour):
            dailiesCompleted += 1
            bestStreak = max(bestStreak, streak)
            if (0..<4).contains(hour) { hits.append(.nightOwl) }
        case .practiceCompleted(let dayKey):
            practicedDays.insert(dayKey)
        }
        hits += Achievement.allCases.filter { count(for: $0) >= $0.target && $0.target > 1 }
        return unlock(hits)
    }

    /// Combines progress from two devices: every counter keeps its highest value and
    /// achievements are the union, so nothing earned is ever lost.
    public func merged(with other: PlayerProgress) -> PlayerProgress {
        var result = self
        result.unlocked.formUnion(other.unlocked)
        result.gamesWon = max(gamesWon, other.gamesWon)
        result.gamesPlayed = max(gamesPlayed, other.gamesPlayed)
        result.dailiesCompleted = max(dailiesCompleted, other.dailiesCompleted)
        result.bestStreak = max(bestStreak, other.bestStreak)
        result.bestScore = max(bestScore, other.bestScore)
        result.practicedDays.formUnion(other.practicedDays)
        return result
    }

    /// Progress towards an achievement, 0...1 (for Game Center's percentage).
    public func progress(of achievement: Achievement) -> Double {
        if unlocked.contains(achievement) { return 1 }
        return min(Double(count(for: achievement)) / Double(achievement.target), 1)
    }

    private func count(for achievement: Achievement) -> Int {
        switch achievement {
        case .tenWins, .fiftyWins, .centennial: gamesWon
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
