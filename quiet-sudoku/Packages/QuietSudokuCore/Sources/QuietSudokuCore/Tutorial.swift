import QuietCore

/// The tutorial, for someone who has never played: one lesson per idea, each on a board from
/// a fixed easy puzzle where the answer follows from what the lesson (and the ones before)
/// taught. `TutorialTests` checks every lesson.
public enum Tutorial {
    public enum Kind: String, CaseIterable, Sendable {
        /// Each row holds 1–9 once: the missing digit of a row.
        case row
        case column
        case box
        /// A digit that fits in only one cell of a box, because its other copies rule out
        /// the rest (hidden single).
        case crossHatch
        /// A cell where only one digit fits (naked single).
        case onlyOne
        /// Pencil marks: every digit that still fits a cell.
        case notes
        /// Mistakes cost points; a hint shows the next step.
        case hint
    }

    public struct Lesson: Hashable, Sendable {
        public let kind: Kind
        /// The board shown (its givens) and its one solution.
        public let puzzle: Puzzle
        public let target: Int
        /// The digit to write (0 for notes).
        public let digit: Int
        /// The notes to write, for `.notes`.
        public let notes: [Int]
        /// Houses to highlight.
        public let units: [Int]
        /// Cells that explain the answer (the other copies of the digit).
        public let clues: [Int]
    }

    /// The easy puzzle every lesson comes from.
    public static let base: Puzzle = Generator.attempt(seed: FNV1a.hash("quiet-sudoku-tutorial"), difficulty: .easy)!

    public static let lessons: [Lesson] = [
        lastInHouse(.row, unit: { Grid.row(of: $0) }),
        lastInHouse(.column, unit: { 9 + Grid.column(of: $0) }),
        lastInHouse(.box, unit: { 18 + Grid.box(of: $0) }),
        crossHatch(),
        onlyOne(),
        notes(),
        hint(),
    ]

    // MARK: Building

    private static var solution: Grid { base.solution }

    private static func puzzle(_ values: [Int]) -> Puzzle {
        Puzzle(givens: Grid(cells: values), solution: solution, difficulty: .easy)
    }

    private static func empties(_ values: [Int], _ unit: Int) -> Int {
        Grid.units[unit].count { values[$0] == 0 }
    }

    /// The first empty cell whose house can be filled up to it while its other two houses
    /// keep at least two empty cells (so only this house gives the answer away).
    private static func lastInHouse(_ kind: Kind, unit: (Int) -> Int) -> Lesson {
        for target in 0..<81 where base.givens[target] == 0 {
            let house = unit(target)
            var values = base.givens.cells
            for cell in Grid.units[house] where cell != target { values[cell] = solution[cell] }
            let others = Grid.unitsOfCell[target].filter { $0 != house }
            guard others.allSatisfy({ empties(values, $0) >= 2 }) else { continue }
            let digit = solution[target]
            return Lesson(kind: kind, puzzle: puzzle(values), target: target, digit: digit, notes: [], units: [house], clues: Grid.units[house].filter { $0 != target })
        }
        fatalError("No \(kind) lesson in the tutorial puzzle")
    }

    /// Positions reached while solving the base puzzle with singles, first to last.
    private static var positions: [LogicSolver] {
        var solver = LogicSolver(base.givens)
        var result = [solver]
        while let step = solver.nextStep(upTo: .easy) {
            solver.apply(step)
            result.append(solver)
        }
        return result
    }

    private static func crossHatch() -> Lesson {
        for state in positions {
            for box in 18..<27 {
                for digit in 1...9 {
                    let spots = Grid.units[box].filter { state.candidates[$0] & Digits.bit(digit) != 0 }
                    guard spots.count == 1, let target = spots.first,
                          state.candidates[target].nonzeroBitCount >= 2,
                          Grid.unitsOfCell[target].allSatisfy({ empties(state.values, $0) >= 2 }) else { continue }
                    let clues = Grid.units[box].filter { $0 != target && state.values[$0] == 0 }
                        .flatMap { cell in Grid.peers[cell].filter { state.values[$0] == digit } }
                    return Lesson(kind: .crossHatch, puzzle: puzzle(state.values), target: target, digit: digit, notes: [], units: [box], clues: Array(Set(clues)).sorted())
                }
            }
        }
        fatalError("No cross-hatching lesson in the tutorial puzzle")
    }

    private static func onlyOne() -> Lesson {
        for state in positions {
            for target in 0..<81 where state.values[target] == 0 && state.candidates[target].nonzeroBitCount == 1 {
                let digit = Digits.single(state.candidates[target])
                // Not also a hidden single or the last cell of a house: only this idea works.
                let alone = Grid.unitsOfCell[target].allSatisfy { unit in
                    empties(state.values, unit) >= 2
                        && Grid.units[unit].count { state.candidates[$0] & Digits.bit(digit) != 0 } >= 2
                }
                guard alone else { continue }
                return Lesson(kind: .onlyOne, puzzle: puzzle(state.values), target: target, digit: digit, notes: [], units: Grid.unitsOfCell[target], clues: Grid.peers[target].filter { state.values[$0] != 0 })
            }
        }
        fatalError("No naked-single lesson in the tutorial puzzle")
    }

    /// A cell with three candidates in the base puzzle.
    private static func notes() -> Lesson {
        let solver = LogicSolver(base.givens)
        let target = (0..<81).first { solver.values[$0] == 0 && solver.candidates[$0].nonzeroBitCount == 3 }!
        return Lesson(kind: .notes, puzzle: base, target: target, digit: 0, notes: Digits.list(solver.candidates[target]), units: Grid.unitsOfCell[target], clues: [])
    }

    /// The base puzzle's first hint.
    private static func hint() -> Lesson {
        guard case .step(let step, _)? = GameSession(puzzle: base).hint(), let placement = step.placement else {
            fatalError("No hint in the tutorial puzzle")
        }
        return Lesson(kind: .hint, puzzle: base, target: placement.cell, digit: placement.digit, notes: [], units: step.units, clues: step.cells)
    }
}
