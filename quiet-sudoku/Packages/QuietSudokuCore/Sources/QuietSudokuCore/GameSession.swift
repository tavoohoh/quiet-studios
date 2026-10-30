/// A game from the first digit to the solved grid: digits, notes, mistakes, undo, hints and score.
public struct GameSession: Codable, Hashable, Sendable {
    public enum Mode: Hashable, Codable, Sendable {
        case classic
        case daily(dayKey: String)
    }

    /// Something worth reacting to (feedback, achievements).
    public enum Event: Hashable, Sendable {
        case placed(cell: Int, digit: Int)
        /// A wrong digit was written; it's charged whether or not it's shown.
        case mistake(cell: Int, scoreAfter: Int)
        /// Houses (0–8 rows, 9–17 columns, 18–26 boxes) the last digit completed.
        case completed(units: [Int])
        /// Every copy of a digit is on the board.
        case digitDone(Int)
        case won(WinSummary)
        case hintCharged(scoreAfter: Int)
    }

    public let mode: Mode
    public let puzzle: Puzzle
    public let scoring: Scoring
    /// Givens and the player's digits; 0 for empty.
    public private(set) var values: [Int]
    /// Pencil marks per cell (bit 0 = digit 1).
    public private(set) var notes: [UInt16]
    /// Points from correct digits, before costs and the win bonus.
    public private(set) var playPoints = 0
    /// Costs never come back with undo.
    public private(set) var mistakeCost = 0
    public private(set) var hintCost = 0
    public private(set) var winBonus = 0
    public private(set) var mistakes = 0
    public private(set) var hintsUsed = 0
    public private(set) var usedUndo = false
    public private(set) var usedNotes = false
    /// Every action (digits, notes, erase, undo), for "games played".
    public private(set) var actions = 0
    public private(set) var elapsedSeconds = 0
    /// Set on a win: the time multiplier (tenths) and the points it added.
    public private(set) var timeMultiplierTenths: Int?
    private var timePoints: Int?
    private var history: [Snapshot] = []

    /// Undo goes back this many actions at most (keeps saved games small).
    static let historyLimit = 200

    /// What an action changed, to put it back.
    private struct Snapshot: Codable, Hashable, Sendable {
        struct Cell: Codable, Hashable, Sendable {
            let cell: Int
            let value: Int
            let notes: UInt16
        }
        let cells: [Cell]
        let playPoints: Int
    }

    public init(mode: Mode = .classic, puzzle: Puzzle, scoring: Scoring = .standard) {
        self.mode = mode
        self.puzzle = puzzle
        self.scoring = scoring
        values = puzzle.givens.cells
        notes = Array(repeating: 0, count: 81)
    }

    /// A game from an exact position (tests, tutorial, screenshots).
    public init(mode: Mode = .classic, puzzle: Puzzle, scoring: Scoring = .standard, values: [Int], notes: [UInt16]? = nil, elapsedSeconds: Int = 0) {
        self.init(mode: mode, puzzle: puzzle, scoring: scoring)
        self.values = values
        self.notes = notes ?? Array(repeating: 0, count: 81)
        self.elapsedSeconds = elapsedSeconds
    }

    public var difficulty: Difficulty { puzzle.difficulty }
    public var score: Int { playPoints + winBonus + timeBonus - mistakeCost - hintCost }
    /// The score without mistake costs, while mistakes aren't shown (they'd give them away).
    public var scoreHidingMistakes: Int { score + mistakeCost }
    public var timeBonus: Int { timePoints ?? 0 }
    public var isWon: Bool { values == puzzle.solution.cells }
    public var canUndo: Bool { !history.isEmpty && !isWon }
    public var hasPlayed: Bool { actions > 0 }
    public var isFull: Bool { !values.contains(0) }

    public func isGiven(_ cell: Int) -> Bool { puzzle.givens[cell] != 0 }
    public func isWrong(_ cell: Int) -> Bool { values[cell] != 0 && values[cell] != puzzle.solution[cell] }
    /// Givens and correct digits can't change: a correct digit can't be erased and written
    /// again for points.
    public func isLocked(_ cell: Int) -> Bool { values[cell] != 0 && !isWrong(cell) }
    public var wrongCells: [Int] { (0..<81).filter(isWrong) }

    /// Correct copies of `digit` on the board (the keypad dims a digit at 9).
    public func count(of digit: Int) -> Int {
        (0..<81).count { values[$0] == digit && !isWrong($0) }
    }

    /// One more second, until the game is won.
    public mutating func tick() {
        guard !isWon else { return }
        elapsedSeconds += 1
    }

    // MARK: Playing

    /// Writes a digit. Returns what happened, or nil if the cell can't take it.
    @discardableResult
    public mutating func place(_ digit: Int, at cell: Int) -> [Event]? {
        guard !isWon, (1...9).contains(digit), !isLocked(cell), values[cell] != digit else { return nil }
        let correct = puzzle.solution[cell] == digit
        // A correct digit also clears that note from the cells it sees.
        let touched = correct ? [cell] + Grid.peers[cell].filter { notes[$0] & Digits.bit(digit) != 0 } : [cell]
        record(touched)
        values[cell] = digit
        notes[cell] = 0
        actions += 1
        guard correct else {
            mistakes += 1
            mistakeCost += scoring.mistake
            return [.mistake(cell: cell, scoreAfter: score)]
        }
        for peer in touched.dropFirst() { notes[peer] &= ~Digits.bit(digit) }
        playPoints += scoring.points(perCell: difficulty)
        return [.placed(cell: cell, digit: digit)] + afterCorrect(cell, digit)
    }

    /// Adds or removes a pencil mark in an empty cell.
    @discardableResult
    public mutating func toggleNote(_ digit: Int, at cell: Int) -> Bool {
        guard !isWon, (1...9).contains(digit), values[cell] == 0 else { return false }
        record([cell])
        notes[cell] ^= Digits.bit(digit)
        usedNotes = true
        actions += 1
        return true
    }

    /// Clears a wrong digit or the notes of a cell.
    @discardableResult
    public mutating func erase(_ cell: Int) -> Bool {
        guard !isWon, !isLocked(cell), values[cell] != 0 || notes[cell] != 0 else { return false }
        record([cell])
        values[cell] = 0
        notes[cell] = 0
        actions += 1
        return true
    }

    /// Back one action. Points it gave go back; mistake and hint costs stay.
    public mutating func undo() {
        guard canUndo, let last = history.popLast() else { return }
        for saved in last.cells {
            values[saved.cell] = saved.value
            notes[saved.cell] = saved.notes
        }
        playPoints = last.playPoints
        actions += 1
        usedUndo = true
    }

    // MARK: Hints

    public enum Hint: Hashable, Sendable {
        /// A wrong digit to clear first.
        case mistake(cell: Int)
        /// The next digit by logic. `step` explains it; `hardest` is the hardest technique
        /// needed on the way (eliminations before the digit appears), if harder than the step.
        case step(Step, hardest: Technique)
    }

    /// The next thing to do: clear a mistake, or the next digit logic can place. Every
    /// puzzle is solvable by the solver, so there's always one until the game is won.
    public func hint() -> Hint? {
        guard !isWon else { return nil }
        if let wrong = wrongCells.first { return .mistake(cell: wrong) }
        var solver = LogicSolver(Grid(cells: values))
        var hardest: Technique?
        while let step = solver.nextStep() {
            hardest = max(hardest ?? step.technique, step.technique)
            if step.placement != nil { return .step(step, hardest: hardest!) }
            solver.apply(step)
        }
        return nil
    }

    /// Charges a hint and does it: clears the mistake or writes the digit (no points for it).
    @discardableResult
    public mutating func apply(_ hint: Hint) -> [Event] {
        hintsUsed += 1
        hintCost += scoring.hint
        var events: [Event] = [.hintCharged(scoreAfter: score)]
        switch hint {
        case .mistake(let cell):
            erase(cell)
        case .step(let step, _):
            guard let placement = step.placement, !isLocked(placement.cell) else { break }
            let digit = placement.digit, cell = placement.cell
            record([cell] + Grid.peers[cell].filter { notes[$0] & Digits.bit(digit) != 0 })
            values[cell] = digit
            notes[cell] = 0
            for peer in Grid.peers[cell] { notes[peer] &= ~Digits.bit(digit) }
            actions += 1
            events += [.placed(cell: cell, digit: digit)] + afterCorrect(cell, digit)
        }
        return events
    }

    // MARK: Private

    private mutating func record(_ cells: [Int]) {
        history.append(Snapshot(cells: cells.map { Snapshot.Cell(cell: $0, value: values[$0], notes: notes[$0]) }, playPoints: playPoints))
        if history.count > Self.historyLimit { history.removeFirst() }
    }

    /// Completed houses, a finished digit and the win.
    private mutating func afterCorrect(_ cell: Int, _ digit: Int) -> [Event] {
        var events: [Event] = []
        let done = Grid.unitsOfCell[cell].filter { unit in Grid.units[unit].allSatisfy(isLocked) }
        if !done.isEmpty { events.append(.completed(units: done)) }
        if count(of: digit) == 9 { events.append(.digitDone(digit)) }
        if isWon {
            winBonus = scoring.winBonus
            let tenths = scoring.timeMultiplierTenths(forSeconds: elapsedSeconds, difficulty: difficulty)
            timeMultiplierTenths = tenths
            timePoints = max(0, (playPoints + winBonus) * (tenths - 10) / 10)
            history = []
            events.append(.won(WinSummary(score: score, seconds: elapsedSeconds, mistakes: mistakes, hintsUsed: hintsUsed, usedUndo: usedUndo, usedNotes: usedNotes, difficulty: difficulty)))
        }
        return events
    }
}

/// How a game was won, for achievements and the summary.
public struct WinSummary: Hashable, Codable, Sendable {
    public let score: Int
    public let seconds: Int
    public let mistakes: Int
    public let hintsUsed: Int
    public let usedUndo: Bool
    public let usedNotes: Bool
    public let difficulty: Difficulty

    public init(score: Int, seconds: Int, mistakes: Int, hintsUsed: Int, usedUndo: Bool, usedNotes: Bool, difficulty: Difficulty) {
        self.score = score
        self.seconds = seconds
        self.mistakes = mistakes
        self.hintsUsed = hintsUsed
        self.usedUndo = usedUndo
        self.usedNotes = usedNotes
        self.difficulty = difficulty
    }
}
