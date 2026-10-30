import Testing
@testable import QuietSudokuCore
import QuietCore

/// Every puzzle the generator gives has one solution and exactly the level it declares.
@Suite struct GradingTests {
    static let samples = 40

    @Test(arguments: Difficulty.allCases)
    func puzzlesAreUniqueAndGradedRight(_ difficulty: Difficulty) {
        for i in 0..<Self.samples {
            let puzzle = Generator.puzzle(key: "grading-\(i)", difficulty: difficulty)
            check(puzzle, difficulty)
        }
    }

    @Test func everyTechniqueIsUsedAndSound() {
        var used: Set<Technique> = []
        var i = 0
        while used.count < Technique.allCases.count, i < 3_000 {
            let level = Difficulty.allCases[i % 4]
            if let puzzle = Generator.build(seed: FNV1a.hash("techniques-\(i)"), upTo: level) {
                for step in LogicSolver.solve(puzzle.givens).steps {
                    used.insert(step.technique)
                    if let p = step.placement { #expect(puzzle.solution[p.cell] == p.digit, "\(step.technique)") }
                    for e in step.eliminations { #expect(puzzle.solution[e.cell] != e.digit, "\(step.technique)") }
                    #expect(step.placement != nil || !step.eliminations.isEmpty)
                }
            }
            i += 1
        }
        #expect(used == Set(Technique.allCases), "never seen: \(Set(Technique.allCases).subtracting(used))")
    }

    @Test func techniqueLevelsFollowTheirOrder() {
        let levels = Technique.allCases.map(\.difficulty)
        #expect(levels == levels.sorted())
        #expect(Set(levels) == Set(Difficulty.allCases))
    }

    @Test func sameKeySamePuzzle() {
        for difficulty in Difficulty.allCases {
            #expect(Generator.puzzle(key: "same", difficulty: difficulty) == Generator.puzzle(key: "same", difficulty: difficulty))
        }
    }

    @Test func clueCountsByLevel() {
        for i in 0..<10 {
            #expect(Generator.puzzle(key: "clues-\(i)", difficulty: .easy).clueCount >= 36)
            #expect(Generator.puzzle(key: "clues-\(i)", difficulty: .medium).clueCount >= 28)
        }
    }

    @Test func symmetricPairsForEasyAndMedium() {
        for difficulty in [Difficulty.easy, .medium] {
            let givens = Generator.puzzle(key: "symmetry", difficulty: difficulty).givens
            #expect((0..<81).allSatisfy { (givens[$0] == 0) == (givens[80 - $0] == 0) })
        }
    }
}

/// Unique (two independent solvers agree), solvable by logic with its level's techniques,
/// and not with the level below.
func check(_ puzzle: Puzzle, _ difficulty: Difficulty, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(puzzle.difficulty == difficulty, sourceLocation: sourceLocation)
    #expect(puzzle.solution.isSolved, sourceLocation: sourceLocation)
    #expect((0..<81).allSatisfy { puzzle.givens[$0] == 0 || puzzle.givens[$0] == puzzle.solution[$0] }, sourceLocation: sourceLocation)
    #expect(DancingLinks.solutions(of: puzzle.givens) == [puzzle.solution], sourceLocation: sourceLocation)
    #expect(Backtracker.countSolutions(puzzle.givens) == 1, sourceLocation: sourceLocation)
    let solved = LogicSolver.solve(puzzle.givens, upTo: difficulty)
    #expect(solved.solved && solved.grid == puzzle.solution, sourceLocation: sourceLocation)
    #expect(solved.hardest.map { $0.difficulty == difficulty } ?? (difficulty == .easy), sourceLocation: sourceLocation)
    if let easier = Difficulty(rawValue: difficulty.rawValue - 1) {
        #expect(!LogicSolver.solve(puzzle.givens, upTo: easier).solved, "\(puzzle.givens.string) solvable at \(easier)", sourceLocation: sourceLocation)
    }
}
