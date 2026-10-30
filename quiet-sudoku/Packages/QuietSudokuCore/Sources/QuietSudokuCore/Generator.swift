import QuietCore

/// A puzzle ready to play: its givens, its one solution and its level.
public struct Puzzle: Hashable, Codable, Sendable {
    public let givens: Grid
    public let solution: Grid
    public let difficulty: Difficulty
    /// The seed that made it (0 for hand-made ones).
    public let seed: UInt64

    public init(givens: Grid, solution: Grid, difficulty: Difficulty, seed: UInt64 = 0) {
        self.givens = givens
        self.solution = solution
        self.difficulty = difficulty
        self.seed = seed
    }

    public var clueCount: Int { givens.filledCount }
}

/// Seed → puzzle, the same on every device: only `SeededRandom`, never the system generator,
/// `shuffled()` or `Hasher`, and budgets counted in attempts rather than time.
public enum Generator {
    /// Removal stops at this many clues, so easy puzzles stay quick to scan.
    static func clueFloor(_ difficulty: Difficulty) -> Int {
        switch difficulty {
        case .easy: 36
        case .medium: 28
        case .hard, .expert: 17
        }
    }

    /// One try from `seed`: a random full grid, then clues removed in symmetric pairs (in a
    /// random order) while the puzzle stays solvable by logic up to `difficulty`. Logic only
    /// ever deduces, so a grid it completes has a single solution; Dancing Links confirms it.
    /// Returns nil when the result isn't exactly `difficulty`.
    public static func attempt(seed: UInt64, difficulty: Difficulty) -> Puzzle? {
        let puzzle = build(seed: seed, upTo: difficulty)
        return puzzle?.difficulty == difficulty ? puzzle : nil
    }

    /// The puzzle a seed makes, removing clues while logic up to `level` still solves it.
    public static func build(seed: UInt64, upTo difficulty: Difficulty) -> Puzzle? {
        var random = SeededRandom(seed: seed)
        let solution = DancingLinks.randomSolution(using: &random)
        var order = Array(0...40)
        for i in stride(from: order.count - 1, to: 0, by: -1) {
            order.swapAt(i, random.nextInt(in: 0...i))
        }
        var givens = solution
        let floor = clueFloor(difficulty)
        for cell in order {
            let pair = cell == 40 ? [40] : [cell, 80 - cell]
            guard givens.filledCount - pair.count >= floor else { continue }
            var candidate = givens
            for c in pair { candidate[c] = 0 }
            if LogicSolver.solve(candidate, upTo: difficulty).solved {
                givens = candidate
            }
        }
        if difficulty >= .hard, LogicSolver.grade(givens) != difficulty {
            // Hard levels rarely appear with pairs alone: break the symmetry one cell at a time.
            for cell in order.flatMap({ $0 == 40 ? [40] : [$0, 80 - $0] }) where givens[cell] != 0 && givens.filledCount > floor {
                var candidate = givens
                candidate[cell] = 0
                if LogicSolver.solve(candidate, upTo: difficulty).solved {
                    givens = candidate
                    if LogicSolver.grade(givens) == difficulty { break }
                }
            }
        }
        guard let grade = LogicSolver.grade(givens), DancingLinks.hasUniqueSolution(givens) else { return nil }
        return Puzzle(givens: givens, solution: solution, difficulty: grade, seed: seed)
    }

    /// Tries `"<key>#0"`, `"<key>#1"`… and keeps the first puzzle of the wanted level. If
    /// none matches within `attempts`, the closest easier one found (never harder).
    public static func puzzle(key: String, difficulty: Difficulty, attempts: Int = 400) -> Puzzle {
        var fallback: Puzzle?
        for attempt in 0..<attempts {
            let seed = FNV1a.hash("\(key)#\(attempt)")
            if let puzzle = Generator.attempt(seed: seed, difficulty: difficulty) { return puzzle }
            if fallback == nil, difficulty > .easy {
                fallback = Generator.attempt(seed: seed, difficulty: Difficulty(rawValue: difficulty.rawValue - 1)!)
            }
        }
        return fallback ?? Generator.attempt(seed: FNV1a.hash(key), difficulty: .easy)!
    }
}
