import Testing
@testable import QuietSudokuCore
import QuietCore

/// Known puzzles from the public literature, used as references for the solvers.
enum Known {
    /// A widely published easy puzzle and its solution.
    static let easy = "53..7....6..195....98....6.8...6...34..8.3..17...2...6.6....28....419..5....8..79"
    static let easySolution = "534678912672195348198342567859761423426853791713924856961537284287419635345286179"
    /// Two clues removed from `easy`: still solvable, but not uniquely.
    static let ambiguous = "53..7....6..195....98....6.8...6...34..8.3..17...2...6.6....28....419..5....8...."
    /// Clashing givens (two 5s in the first row).
    static let invalid = "55..7....6..195....98....6.8...6...34..8.3..17...2...6.6....28....419..5....8..79"
}

@Suite struct DancingLinksTests {
    @Test func solvesKnownPuzzle() {
        let solutions = DancingLinks.solutions(of: Grid(Known.easy)!)
        #expect(solutions.count == 1)
        #expect(solutions.first?.string == Known.easySolution)
    }

    @Test func detectsMultipleSolutions() {
        #expect(DancingLinks.countSolutions(Grid(Known.ambiguous)!) == 2)
        #expect(Backtracker.countSolutions(Grid(Known.ambiguous)!) == 2)
    }

    @Test func rejectsClashingGivens() {
        #expect(DancingLinks.countSolutions(Grid(Known.invalid)!) == 0)
        #expect(Backtracker.countSolutions(Grid(Known.invalid)!) == 0)
    }

    @Test func emptyGridHasMany() {
        #expect(DancingLinks.countSolutions(Grid()) == 2)
    }

    /// Minimal puzzles (no clue can go without losing uniqueness) are the hardest case for
    /// uniqueness checks; both solvers must agree on every clue.
    @Test func minimalPuzzlesAgree() {
        for seed in UInt64(1)...5 {
            var random = SeededRandom(seed: seed)
            let solution = DancingLinks.randomSolution(using: &random)
            var grid = solution
            for cell in 0..<81 {
                var candidate = grid
                candidate[cell] = 0
                if DancingLinks.hasUniqueSolution(candidate) { grid = candidate }
            }
            #expect(DancingLinks.solutions(of: grid) == [solution])
            #expect(Backtracker.countSolutions(grid) == 1)
            for cell in 0..<81 where grid[cell] != 0 {
                var candidate = grid
                candidate[cell] = 0
                #expect(DancingLinks.countSolutions(candidate) == 2)
                #expect(Backtracker.countSolutions(candidate) == 2)
            }
        }
    }

    @Test func randomSolutionsAreValidAndDeterministic() {
        for seed in UInt64(1)...20 {
            var a = SeededRandom(seed: seed), b = SeededRandom(seed: seed)
            let grid = DancingLinks.randomSolution(using: &a)
            #expect(grid.isSolved)
            #expect(grid == DancingLinks.randomSolution(using: &b))
        }
        var a = SeededRandom(seed: 1), b = SeededRandom(seed: 2)
        #expect(DancingLinks.randomSolution(using: &a) != DancingLinks.randomSolution(using: &b))
    }

    @Test func gridParsing() {
        let grid = Grid(Known.easy)!
        #expect(grid.string == Known.easy)
        #expect(grid.filledCount == 30)
        #expect(Grid("123") == nil)
        #expect(Grid.peers.allSatisfy { $0.count == 20 })
        #expect(Grid.units.allSatisfy { Set($0).count == 9 })
    }
}

@Suite struct LogicSolverTests {
    @Test func solvesEasyWithSingles() {
        let result = LogicSolver.solve(Grid(Known.easy)!, upTo: .easy)
        #expect(result.solved)
        #expect(result.grid.string == Known.easySolution)
        #expect(result.difficulty == .easy)
    }

    @Test func stopsWhenTechniquesRunOut() {
        let expert = Generator.puzzle(key: "stuck", difficulty: .expert)
        let result = LogicSolver.solve(expert.givens, upTo: .hard)
        #expect(!result.solved)
        #expect(result.grid.filledCount > expert.clueCount)
    }

    @Test func everyStepAgreesWithTheSolution() {
        // Sound steps: no placement or elimination ever contradicts the unique solution.
        for key in ["a", "b", "c", "d"] {
            for difficulty in Difficulty.allCases {
                let puzzle = Generator.puzzle(key: key, difficulty: difficulty)
                for step in LogicSolver.solve(puzzle.givens).steps {
                    if let p = step.placement { #expect(puzzle.solution[p.cell] == p.digit) }
                    for e in step.eliminations { #expect(puzzle.solution[e.cell] != e.digit, "\(step.technique)") }
                }
            }
        }
    }
}
