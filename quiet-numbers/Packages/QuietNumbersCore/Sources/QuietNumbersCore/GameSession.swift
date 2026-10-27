/// Point values. Initial values from the brief; tweak here.
public struct Scoring: Codable, Hashable, Sendable {
    public var adjacentPair = 1
    public var acrossClearedPair = 4
    public var rowCleared = 10
    public var boardClearedPerStage = 150
    /// Hints are unlimited but cost points, even if that takes the score below zero.
    public var hintCost = 10
    /// From this stage on, every pair is worth one more point.
    public static let pairBonusFromStage = 3

    public static let standard = Scoring()
    /// "In the Red"'s hidden reward, outside the scored daily challenge: hints cost 3.
    public static let cheapHints = {
        var scoring = Scoring()
        scoring.hintCost = 3
        return scoring
    }()

    public func points(for connection: Connection, stage: Int = 1) -> Int {
        let base = switch connection {
        case .adjacent: adjacentPair
        case .acrossCleared: acrossClearedPair
        }
        return base + (stage >= Self.pairBonusFromStage ? 1 : 0)
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
    /// The two numbers, in board order.
    public let values: [Int]
    /// Rows removed, as row indices before removal.
    public let clearedRows: [Int]
    /// Digits with no active cell left after this match (e.g. the last 7 is gone).
    public let clearedDigits: [Int]
    public let boardCleared: Bool
    /// Stage after this match (the next one if the board was cleared in classic).
    public let stage: Int
    /// Hints used on this board, and whether + was used on it (up to this match).
    public var hintsOnBoard = 0
    public var usedPlusOnBoard = false
}

/// A full game: board, score, stages and the + budget.
public struct GameSession: Codable, Hashable, Sendable {
    /// + uses per board at stage 1 (the most). Clearing rows doesn't give any back.
    public static let maxPlusUses = 5

    /// Fewer + as stages go: 5, then 4 from stage 3, then 3 from stage 5.
    public static func plusUses(forStage stage: Int) -> Int {
        switch stage {
        case ...2: maxPlusUses
        case 3...4: 4
        default: 3
        }
    }

    /// State before the last move, so it can be undone once.
    private struct UndoPoint: Codable, Hashable, Sendable {
        var board: Board
        var score: Int
        var plusRemaining: Int
        var streak: Int
    }

    public let mode: GameMode
    public let scoring: Scoring
    public private(set) var board: Board
    public private(set) var score = 0
    public private(set) var stage = 1
    public private(set) var plusRemaining = maxPlusUses
    /// Hints used in the whole game (for the "no help" achievement).
    public private(set) var hintsUsed = 0
    /// Valid matches in a row. A miss or a hint resets it; + doesn't.
    public private(set) var streak = 0
    /// Daily challenge only: the board was cleared.
    public private(set) var isCompleted = false
    /// `hintsUsed` when this board started. Optional so games saved before it still load.
    private var hintsAtBoardStart: Int?
    private var random: SeededRandom
    private var undoPoint: UndoPoint?

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

    /// Hints used on the current board (for "No Help").
    public var hintsOnBoard: Int { hintsUsed - (hintsAtBoardStart ?? 0) }

    /// + was used on the current board (for "Clean Slate").
    public var usedPlusOnBoard: Bool { plusRemaining < Self.plusUses(forStage: stage) }

    /// Anything was played: a match, a + or a hint.
    public var hasMoves: Bool { score != 0 || stage > 1 || hintsUsed > 0 || usedPlusOnBoard }

    /// No pairs left and no + uses left.
    public var isOver: Bool { isCompleted || (!hasValidPair && plusRemaining == 0) }

    /// The last match or + can be taken back: one step only, not across a cleared
    /// board, and not once the game is over.
    public var canUndo: Bool { undoPoint != nil && !isOver }

    public mutating func match(cellID a: Int, _ b: Int) -> MatchOutcome? {
        guard let first = board.index(ofCell: a), let second = board.index(ofCell: b) else { return nil }
        return match(at: first, second)
    }

    public mutating func match(at a: Int, _ b: Int) -> MatchOutcome? {
        guard !isOver, let pair = MatchRules.pair(on: board, a, b) else { return nil }

        let undo = checkpoint()
        let values = [board.cells[pair.first].value, board.cells[pair.second].value]
        board.clear(at: pair.first)
        board.clear(at: pair.second)
        var points = scoring.points(for: pair.connection, stage: stage)

        let rows = board.removeClearedRows([board.row(of: pair.first), board.row(of: pair.second)])
        points += rows.count * scoring.rowCleared

        let remaining = Set(board.activeValues)
        let clearedDigits = Set(values).filter { !remaining.contains($0) }.sorted()
        let boardCleared = board.isEmpty
        if boardCleared {
            points += scoring.boardClearedPerStage * stage
        }
        score += points
        streak += 1
        undoPoint = boardCleared ? nil : undo
        let hintsOnBoard = self.hintsOnBoard, usedPlusOnBoard = self.usedPlusOnBoard
        if boardCleared { advanceStage() }

        return MatchOutcome(
            pair: pair,
            points: points,
            values: values,
            clearedRows: rows,
            clearedDigits: clearedDigits,
            boardCleared: boardCleared,
            stage: stage,
            hintsOnBoard: hintsOnBoard,
            usedPlusOnBoard: usedPlusOnBoard
        )
    }

    /// Copies every remaining number, in order, to the end of the board.
    @discardableResult
    public mutating func addNumbers() -> Bool {
        guard plusRemaining > 0, !isOver else { return false }
        undoPoint = checkpoint()
        plusRemaining -= 1
        board.append(board.activeValues)
        return true
    }

    /// Returns a valid pair and charges `scoring.hintCost`.
    /// Free (and `nil`) when there's no pair to show.
    public mutating func useHint() -> (pair: Pair, cost: Int)? {
        guard !isOver, let pair = MatchRules.validPairs(on: board).first else { return nil }
        let cost = scoring.hintCost
        score -= cost
        hintsUsed += 1
        streak = 0
        // Undoing later mustn't refund the hint or bring the streak back.
        if var point = undoPoint {
            point.score -= cost
            point.streak = 0
            undoPoint = point
        }
        return (pair, cost)
    }

    /// The player tried a pair that doesn't match.
    public mutating func registerMiss() {
        streak = 0
        undoPoint?.streak = 0
    }

    /// Takes back the last match or +. Returns false if there's nothing to undo.
    @discardableResult
    public mutating func undo() -> Bool {
        guard canUndo, let point = undoPoint else { return false }
        board = point.board
        score = point.score
        plusRemaining = point.plusRemaining
        streak = point.streak
        undoPoint = nil
        return true
    }

    private func checkpoint() -> UndoPoint {
        UndoPoint(board: board, score: score, plusRemaining: plusRemaining, streak: streak)
    }

    private mutating func advanceStage() {
        switch mode {
        case .daily:
            isCompleted = true
        case .classic:
            stage += 1
            plusRemaining = Self.plusUses(forStage: stage)
            hintsAtBoardStart = hintsUsed
            board = BoardGenerator.makeBoard(using: &random, stage: stage)
        }
    }
}

extension GameSession {
    /// Starts from a hand-made position (tests, App Store screenshots).
    public init(board: Board, mode: GameMode = .classic, seed: UInt64 = 0, plusRemaining: Int = maxPlusUses, stage: Int = 1, score: Int = 0) {
        self.init(mode: mode, seed: seed)
        self.board = board
        self.plusRemaining = plusRemaining
        self.stage = stage
        self.score = score
    }
}
