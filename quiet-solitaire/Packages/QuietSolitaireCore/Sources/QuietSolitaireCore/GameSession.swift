import QuietCore

/// A game from deal to win: moves, undo, hints and score.
public struct GameSession: Codable, Hashable, Sendable {
    public enum Mode: Hashable, Codable, Sendable {
        case classic
        case daily(dayKey: String)
    }

    /// Something worth reacting to (feedback, achievements).
    public enum Event: Hashable, Sendable {
        case moved(Move, GameState.Outcome)
        case won(WinSummary)
        /// A king-to-ace run stands in one column.
        case ladder
        case hintCharged(scoreAfter: Int)
    }

    public let mode: Mode
    public let seed: UInt64
    public let scoring: Scoring
    public private(set) var state: GameState
    /// Points from play, before hint costs and the win bonus.
    public private(set) var playPoints = 0
    /// Hint costs so far. Undo never refunds them.
    public private(set) var hintCost = 0
    public private(set) var winBonus = 0
    public private(set) var moves = 0
    public private(set) var hintsUsed = 0
    public private(set) var usedUndo = false
    public private(set) var recycles = 0
    /// Seconds played. Optional so games saved before the clock still load.
    private var elapsed: Int?
    /// Set on a win: the time multiplier (tenths) and the points it added.
    private var timeMultiplier: Int?
    private var timePoints: Int?
    private var history: [Snapshot] = []

    /// Undo goes back this many moves at most (keeps saved games small).
    static let historyLimit = 200

    private struct Snapshot: Codable, Hashable, Sendable {
        let state: GameState
        let playPoints: Int
        let recycles: Int
    }

    public init(mode: Mode = .classic, seed: UInt64, scoring: Scoring = .standard) {
        self.init(mode: mode, seed: seed, scoring: scoring, state: .deal(seed: seed))
    }

    /// A game from an exact table (tests, tutorial, screenshots). `elapsedSeconds` presets
    /// the clock (screenshots of a win at a given time).
    public init(mode: Mode = .classic, seed: UInt64 = 0, scoring: Scoring = .standard, state: GameState, elapsedSeconds: Int = 0) {
        self.mode = mode
        self.seed = seed
        self.scoring = scoring
        self.state = state
        elapsed = elapsedSeconds > 0 ? elapsedSeconds : nil
    }

    public var score: Int { playPoints - hintCost + winBonus + timeBonus }

    /// Extra points from finishing fast (the multiplier applied to play points and the move bonus).
    public var timeBonus: Int { timePoints ?? 0 }
    /// ×1.0…×2.0 in tenths, once won.
    public var timeMultiplierTenths: Int? { timeMultiplier }

    /// Time spent on this game, counted by the app while the game is on screen.
    /// Shown only: it doesn't change the score.
    public var elapsedSeconds: Int { elapsed ?? 0 }

    /// One more second, once the game has started and until it's won.
    public mutating func tick() {
        guard moves > 0, !isWon else { return }
        elapsed = elapsedSeconds + 1
    }
    public var isWon: Bool { state.isWon }
    public var canUndo: Bool { !history.isEmpty && !isWon }
    /// Anything played yet (for "games played").
    public var hasMoves: Bool { moves > 0 }

    // MARK: Playing

    /// Plays a move if it's legal. Returns what happened, or nil if it wasn't allowed.
    @discardableResult
    public mutating func play(_ move: Move) -> [Event]? {
        guard !isWon, state.isLegal(move) else { return nil }
        history.append(Snapshot(state: state, playPoints: playPoints, recycles: recycles))
        if history.count > Self.historyLimit { history.removeFirst() }
        let points = points(for: move)
        let outcome = state.apply(move)
        playPoints += points + (outcome.flipped ? scoring.flip : 0)
        if outcome.recycled {
            recycles += 1
            playPoints += scoring.recycle
        }
        moves += 1
        var events: [Event] = [.moved(move, outcome)]
        if case .move(_, _, .tableau(let column)) = move, hasLadder(in: column) { events.append(.ladder) }
        if state.isWon {
            winBonus = scoring.bonus(forMoves: moves)
            let tenths = scoring.timeMultiplierTenths(forSeconds: elapsedSeconds)
            timeMultiplier = tenths
            timePoints = max(0, (playPoints + winBonus) * (tenths - 10) / 10)
            events.append(.won(WinSummary(score: score, moves: moves, usedUndo: usedUndo, hintsUsed: hintsUsed, recycles: recycles, seconds: elapsedSeconds)))
        }
        return events
    }

    /// Back one move. Counts as a move, takes back the points it gave; hint costs stay.
    public mutating func undo() {
        guard canUndo, let last = history.popLast() else { return }
        state = last.state
        playPoints = last.playPoints
        recycles = last.recycles
        moves += 1
        usedUndo = true
    }

    /// Charges a hint. The suggestion itself comes from `suggestion(for:)` (slow: run it off
    /// the main thread); only charge when it found something.
    public mutating func chargeHint() -> Event {
        hintsUsed += 1
        hintCost += scoring.hint
        return .hintCharged(scoreAfter: score)
    }

    /// The solver's next move when it finds a win; otherwise a sensible legal move, or a draw.
    public static func suggestion(for state: GameState, budget: Int = 20_000) -> Move? {
        if case .solved(let move?, _) = Solver.solve(state, budget: budget) { return move }
        let moves = state.legalMoves.filter { move in
            // Back-and-forth moves between columns aren't useful advice.
            guard case .move(let from, let count, .tableau) = move else { return true }
            if case .tableau(let column) = from {
                let start = state.tableau[column].count - count
                return start == 0 || !state.tableau[column][start - 1].isFaceUp
            }
            return from == .waste
        }
        if let toFoundation = moves.first(where: { if case .move(_, _, .foundation) = $0 { true } else { false } }) {
            return toFoundation
        }
        return moves.first ?? (state.isLegal(.draw) ? .draw : nil)
    }

    private func points(for move: Move) -> Int {
        guard case .move(let from, _, let to) = move else { return 0 }
        switch (from, to) {
        case (_, .foundation) where !isFoundation(from): return scoring.toFoundation
        case (.waste, .tableau): return scoring.wasteToTableau
        case (.foundation, .tableau): return scoring.foundationToTableau
        default: return 0
        }
    }

    private func isFoundation(_ location: Location) -> Bool {
        if case .foundation = location { true } else { false }
    }

    /// The column holds a face-up run from king to ace.
    private func hasLadder(in column: Int) -> Bool {
        let cards = state.tableau[column]
        guard cards.count >= 13 else { return false }
        let start = cards.count - 13
        return cards[start].card.rank == 13 && state.runLength(column: column, from: start) == 13
    }
}

/// How a game was won, for achievements and the end screen.
public struct WinSummary: Hashable, Codable, Sendable {
    public let score: Int
    public let moves: Int
    public let usedUndo: Bool
    public let hintsUsed: Int
    public let recycles: Int
    /// Optional so summaries saved before the clock still load.
    public let seconds: Int?

    public init(score: Int, moves: Int, usedUndo: Bool, hintsUsed: Int, recycles: Int, seconds: Int?) {
        self.score = score
        self.moves = moves
        self.usedUndo = usedUndo
        self.hintsUsed = hintsUsed
        self.recycles = recycles
        self.seconds = seconds
    }
}
