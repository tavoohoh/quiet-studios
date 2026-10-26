/// Achievements. Each one unlocks a cosmetic reward; none affect play.
public enum Achievement: String, CaseIterable, Codable, Sendable {
    /// Finish a first game.
    case firstStep
    /// Clear a whole board.
    case cleanSlate
    /// Finish a game without using any hint (+ is fine).
    case noHelp
    /// 7-day daily streak.
    case consistency
    /// 30-day daily streak.
    case habit
    /// Clear 100 rows in total.
    case sweeper
    /// Reach stage 5 in one game.
    case stageFive
    /// Complete 100 daily challenges.
    case centennial
    /// Complete a daily between 00:00 and 04:00 local time.
    case nightOwl
    /// 10 pairs of equal numbers in a row (4-4, 7-7…).
    case monotone
    /// Take the score below zero with hints.
    case inTheRed

    /// Amount needed for counted achievements; 1 for one-off ones.
    public var target: Int {
        switch self {
        case .consistency: 7
        case .habit: 30
        case .sweeper: 100
        case .stageFive: 5
        case .centennial: 100
        case .monotone: 10
        case .firstStep, .cleanSlate, .noHelp, .nightOwl, .inTheRed: 1
        }
    }
}

/// Something that happened in play, fed to `PlayerProgress`.
public enum ProgressEvent: Sendable {
    case matched(MatchOutcome)
    /// The player tried a pair that doesn't match.
    case missed
    /// A hint was charged, leaving the score at `scoreAfter`.
    case hintUsed(scoreAfter: Int)
    /// The player undid this match; its counters are taken back (unlocks stay).
    case undone(MatchOutcome)
    /// A game reached its end (classic game over, or a daily attempt finished).
    /// `classicScore` is set for classic games, for the best-score leaderboard.
    case gameFinished(classicScore: Int?, hintsUsed: Int)
    /// A classic game was replaced by a new one before it ended; its score still counts as a best.
    case classicAbandoned(score: Int)
    /// A daily challenge was completed (board cleared) on its own day.
    case dailyCompleted(currentStreak: Int, localHour: Int)
}

/// Lifetime counters and unlocked achievements. Stored locally; works without Game Center.
public struct PlayerProgress: Codable, Hashable, Sendable {
    public private(set) var unlocked: Set<Achievement> = []
    public private(set) var gamesFinished = 0
    public private(set) var boardsCleared = 0
    public private(set) var rowsCleared = 0
    public private(set) var highestStage = 1
    public private(set) var dailiesCompleted = 0
    public private(set) var bestStreak = 0
    /// Equal-number pairs in a row, in the current game.
    public private(set) var equalPairsRun = 0
    public private(set) var bestEqualPairsRun = 0
    /// Best final score in classic mode.
    public private(set) var bestScore = 0

    public init() {}

    /// Starts with achievements already unlocked (QA and screenshots).
    public init(unlocked: Set<Achievement>) {
        self.unlocked = unlocked
    }

    /// Applies an event and returns achievements unlocked by it.
    public mutating func record(_ event: ProgressEvent) -> [Achievement] {
        var hits: [Achievement] = []
        switch event {
        case .matched(let outcome):
            rowsCleared += outcome.clearedRows.count
            highestStage = max(highestStage, outcome.stage)
            if outcome.values[0] == outcome.values[1] {
                equalPairsRun += 1
                bestEqualPairsRun = max(bestEqualPairsRun, equalPairsRun)
            } else {
                equalPairsRun = 0
            }
            if outcome.boardCleared { boardsCleared += 1 }
        case .missed:
            break
        case .hintUsed(let score):
            if score < 0 { hits.append(.inTheRed) }
        case .undone(let outcome):
            rowsCleared = max(0, rowsCleared - outcome.clearedRows.count)
            if outcome.values[0] == outcome.values[1] {
                equalPairsRun = max(0, equalPairsRun - 1)
            }
        case .gameFinished(let classicScore, let hintsUsed):
            gamesFinished += 1
            equalPairsRun = 0
            if let classicScore { bestScore = max(bestScore, classicScore) }
            if hintsUsed == 0 { hits.append(.noHelp) }
        case .classicAbandoned(let score):
            equalPairsRun = 0
            bestScore = max(bestScore, score)
        case .dailyCompleted(let streak, let hour):
            dailiesCompleted += 1
            bestStreak = max(bestStreak, streak)
            if (0..<4).contains(hour) { hits.append(.nightOwl) }
        }
        hits += Achievement.allCases.filter { count(for: $0) >= $0.target }
        return unlock(hits)
    }

    /// Combines progress from two devices (Game Center saved games): every counter keeps
    /// its highest value and achievements are the union, so nothing earned is ever lost.
    public func merged(with other: PlayerProgress) -> PlayerProgress {
        var result = self
        result.unlocked.formUnion(other.unlocked)
        result.gamesFinished = max(gamesFinished, other.gamesFinished)
        result.boardsCleared = max(boardsCleared, other.boardsCleared)
        result.rowsCleared = max(rowsCleared, other.rowsCleared)
        result.highestStage = max(highestStage, other.highestStage)
        result.dailiesCompleted = max(dailiesCompleted, other.dailiesCompleted)
        result.bestStreak = max(bestStreak, other.bestStreak)
        result.bestEqualPairsRun = max(bestEqualPairsRun, other.bestEqualPairsRun)
        result.bestScore = max(bestScore, other.bestScore)
        return result
    }

    /// Progress towards an achievement, 0...1 (for Game Center's percentage).
    public func progress(of achievement: Achievement) -> Double {
        if unlocked.contains(achievement) { return 1 }
        return min(Double(count(for: achievement)) / Double(achievement.target), 1)
    }

    /// Current count for counted achievements; one-offs report 0 until unlocked.
    private func count(for achievement: Achievement) -> Int {
        switch achievement {
        case .firstStep: gamesFinished
        case .cleanSlate: boardsCleared
        case .consistency, .habit: bestStreak
        case .sweeper: rowsCleared
        case .stageFive: highestStage
        case .centennial: dailiesCompleted
        case .monotone: bestEqualPairsRun
        case .noHelp, .nightOwl, .inTheRed: 0
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
