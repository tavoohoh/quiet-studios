/// Point values. Initial values from the brief; tweak here.
public struct Scoring: Codable, Hashable, Sendable {
    public var adjacentPair = 1
    public var acrossClearedPair = 4
    public var rowCleared = 10
    public var boardClearedPerStage = 150
    /// Hints are unlimited but cost points. The score never drops below zero.
    public var hintCost = 3

    public static let standard = Scoring()

    public func points(for connection: Connection) -> Int {
        switch connection {
        case .adjacent: adjacentPair
        case .acrossCleared: acrossClearedPair
        }
    }
}

public enum GameMode: Codable, Hashable, Sendable {
    case classic
    /// One stage only. `dayKey` is `yyyy-MM-dd` (UTC).
    case daily(dayKey: String)
}

/// What a successful match did, so the UI can animate and give feedback.
public struct MatchOutcome: Equatable, Sendable {
    public let pair: Pair
    public let points: Int
    /// Rows removed, as row indices before removal.
    public let clearedRows: [Int]
    public let boardCleared: Bool
}

/// A full game: board, score, stages and the + budget.
public struct GameSession: Codable, Hashable, Sendable {
    public static let maxPlusUses = 5

    public let mode: GameMode
    public let scoring: Scoring
    public private(set) var board: Board
    public private(set) var score = 0
    public private(set) var stage = 1
    public private(set) var plusRemaining = maxPlusUses
    /// Hints used in the current stage (for "no help" achievements).
    public private(set) var hintsUsedThisStage = 0
    /// Valid matches in a row. A miss or a hint resets it; + doesn't.
    public private(set) var streak = 0
    /// Daily challenge only: the board was cleared.
    public private(set) var isCompleted = false
    private var random: SeededRandom

    public init(mode: GameMode = .classic, seed: UInt64, scoring: Scoring = .standard) {
        self.mode = mode
        self.scoring = scoring
        random = SeededRandom(seed: seed)
        board = BoardGenerator.makeBoard(using: &random)
    }

    /// Starts from exact numbers instead of a generated board (tutorials, UI tests).
    /// Later stages are generated from `seed`.
    public init(values: [Int], mode: GameMode = .classic, seed: UInt64, scoring: Scoring = .standard) {
        self.init(mode: mode, seed: seed, scoring: scoring)
        board = Board(values: values)
    }

    public var hasValidPair: Bool { MatchRules.hasValidPair(on: board) }

    /// No pairs left and no + uses left.
    public var isOver: Bool { isCompleted || (!hasValidPair && plusRemaining == 0) }

    public mutating func match(cellID a: Int, _ b: Int) -> MatchOutcome? {
        guard let first = board.index(ofCell: a), let second = board.index(ofCell: b) else { return nil }
        return match(at: first, second)
    }

    public mutating func match(at a: Int, _ b: Int) -> MatchOutcome? {
        guard !isOver, let pair = MatchRules.pair(on: board, a, b) else { return nil }

        board.clear(at: pair.first)
        board.clear(at: pair.second)
        var points = scoring.points(for: pair.connection)

        let rows = board.removeClearedRows([board.row(of: pair.first), board.row(of: pair.second)])
        points += rows.count * scoring.rowCleared
        plusRemaining = min(Self.maxPlusUses, plusRemaining + rows.count)

        let boardCleared = board.isEmpty
        if boardCleared {
            points += scoring.boardClearedPerStage * stage
        }
        score += points
        streak += 1
        if boardCleared { advanceStage() }

        return MatchOutcome(pair: pair, points: points, clearedRows: rows, boardCleared: boardCleared)
    }

    /// Copies every remaining number, in order, to the end of the board.
    @discardableResult
    public mutating func addNumbers() -> Bool {
        guard plusRemaining > 0, !isOver else { return false }
        plusRemaining -= 1
        board.append(board.activeValues)
        return true
    }

    /// Returns a valid pair and charges `scoring.hintCost`.
    /// Free (and `nil`) when there's no pair to show.
    public mutating func useHint() -> (pair: Pair, cost: Int)? {
        guard !isOver, let pair = MatchRules.validPairs(on: board).first else { return nil }
        let cost = min(score, scoring.hintCost)
        score -= cost
        hintsUsedThisStage += 1
        streak = 0
        return (pair, cost)
    }

    /// The player tried a pair that doesn't match.
    public mutating func registerMiss() {
        streak = 0
    }

    private mutating func advanceStage() {
        switch mode {
        case .daily:
            isCompleted = true
        case .classic:
            stage += 1
            plusRemaining = Self.maxPlusUses
            hintsUsedThisStage = 0
            board = BoardGenerator.makeBoard(using: &random)
        }
    }
}

extension GameSession {
    /// Test hook: start from a hand-made board.
    init(board: Board, mode: GameMode = .classic, seed: UInt64 = 0, plusRemaining: Int = maxPlusUses, stage: Int = 1, score: Int = 0) {
        self.init(mode: mode, seed: seed)
        self.board = board
        self.plusRemaining = plusRemaining
        self.stage = stage
        self.score = score
    }
}
