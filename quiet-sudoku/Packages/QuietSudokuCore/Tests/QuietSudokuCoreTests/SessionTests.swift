import Testing
@testable import QuietSudokuCore

@Suite struct SessionTests {
    let puzzle = Generator.puzzle(key: "session", difficulty: .easy)
    var empty: [Int] { (0..<81).filter { puzzle.givens[$0] == 0 } }

    func wrongDigit(at cell: Int) -> Int { puzzle.solution[cell] % 9 + 1 }

    @Test func correctDigitScoresAndLocks() {
        var game = GameSession(puzzle: puzzle)
        let cell = empty[0]
        let events = game.place(puzzle.solution[cell], at: cell)
        #expect(events?.first == .placed(cell: cell, digit: puzzle.solution[cell]))
        #expect(game.score == 10)
        #expect(game.isLocked(cell))
        let erased = game.erase(cell)
        #expect(!erased)
        let replaced = game.place(wrongDigit(at: cell), at: cell)
        #expect(replaced == nil)
    }

    @Test func givensCantChange() {
        var game = GameSession(puzzle: puzzle)
        let given = (0..<81).first { puzzle.givens[$0] != 0 }!
        let placed = game.place(wrongDigit(at: given), at: given)
        let erased = game.erase(given)
        let noted = game.toggleNote(1, at: given)
        #expect(placed == nil && !erased && !noted)
    }

    @Test func mistakeCostsAndStays() {
        var game = GameSession(puzzle: puzzle)
        let cell = empty[0]
        let events = game.place(wrongDigit(at: cell), at: cell)
        #expect(events == [.mistake(cell: cell, scoreAfter: -20)])
        #expect(game.mistakes == 1)
        #expect(game.isWrong(cell))
        #expect(game.scoreHidingMistakes == 0)
        // Erasing or undoing doesn't give the cost back.
        let erased = game.erase(cell)
        #expect(erased)
        game.undo()
        #expect(game.score == -20)
        game.undo()
        #expect(game.values[cell] == 0)
        #expect(game.score == -20)
        // The right digit replaces a wrong one.
        game.place(wrongDigit(at: cell), at: cell)
        game.place(puzzle.solution[cell], at: cell)
        #expect(game.mistakes == 2)
        #expect(game.score == -30)
    }

    @Test func notesToggleAndClearFromPeers() {
        var game = GameSession(puzzle: puzzle)
        let cell = empty[0]
        let digit = puzzle.solution[cell]
        let peer = Grid.peers[cell].first { puzzle.givens[$0] == 0 }!
        let noted = game.toggleNote(digit, at: peer)
        #expect(noted)
        #expect(game.notes[peer] & Digits.bit(digit) != 0)
        #expect(game.usedNotes)
        game.place(digit, at: cell)
        #expect(game.notes[peer] & Digits.bit(digit) == 0)
        // Undo brings the note back.
        game.undo()
        #expect(game.notes[peer] & Digits.bit(digit) != 0)
        #expect(game.values[cell] == 0)
        #expect(game.score == 0)
        #expect(game.usedUndo)
    }

    @Test func wrongDigitLeavesPeerNotes() {
        var game = GameSession(puzzle: puzzle)
        let cell = empty[0]
        let wrong = wrongDigit(at: cell)
        let peer = Grid.peers[cell].first { puzzle.givens[$0] == 0 }!
        game.toggleNote(wrong, at: peer)
        game.place(wrong, at: cell)
        #expect(game.notes[peer] & Digits.bit(wrong) != 0)
    }

    @Test func notesOnlyInEmptyCells() {
        var game = GameSession(puzzle: puzzle)
        let cell = empty[0]
        game.toggleNote(3, at: cell)
        game.place(puzzle.solution[cell], at: cell)
        #expect(game.notes[cell] == 0)
        let noted = game.toggleNote(3, at: cell)
        #expect(!noted)
    }

    @Test func winWithBonusAndTimeMultiplier() {
        var game = GameSession(puzzle: puzzle)
        for _ in 0..<100 { game.tick() }
        var last: [GameSession.Event] = []
        for cell in empty { last = game.place(puzzle.solution[cell], at: cell)! }
        #expect(game.isWon)
        guard case .won(let summary) = last.last else { Issue.record("no win"); return }
        // Under the easy target (5 min): ×2 on digits and bonus.
        let points = empty.count * 10
        #expect(game.timeMultiplierTenths == 20)
        #expect(summary.score == (points + 500) * 2)
        #expect(summary.mistakes == 0 && summary.hintsUsed == 0 && !summary.usedNotes)
        #expect(!game.canUndo)
        game.tick()
        #expect(game.elapsedSeconds == 100)
    }

    @Test func completingHousesIsReported() {
        var game = GameSession(puzzle: puzzle)
        var completed: Set<Int> = []
        for cell in empty {
            for event in game.place(puzzle.solution[cell], at: cell)! {
                if case .completed(let units) = event { completed.formUnion(units) }
            }
        }
        // Every house without givens filling it already is reported once finished.
        let alreadyFull = (0..<27).filter { Grid.units[$0].allSatisfy { puzzle.givens[$0] != 0 } }
        #expect(completed.union(alreadyFull) == Set(0..<27))
    }

    @Test func hintClearsMistakeFirst() {
        var game = GameSession(puzzle: puzzle)
        let cell = empty[3]
        game.place(wrongDigit(at: cell), at: cell)
        #expect(game.hint() == .mistake(cell: cell))
        game.apply(game.hint()!)
        #expect(game.values[cell] == 0)
        #expect(game.score == -30)
    }

    @Test func hintsAlwaysFinishAPuzzle() {
        // The hint never runs out: any level can be finished with hints alone.
        for difficulty in Difficulty.allCases {
            var game = GameSession(puzzle: Generator.puzzle(key: "hints", difficulty: difficulty))
            var count = 0
            while let hint = game.hint() {
                if case .step(let step, let hardest) = hint {
                    #expect(step.placement != nil)
                    #expect(hardest.difficulty <= difficulty)
                }
                game.apply(hint)
                count += 1
            }
            #expect(game.isWon)
            #expect(count == game.puzzle.givens.cells.count { $0 == 0 })
            #expect(game.score == 500 * 2 - count * 10)
        }
    }

    @Test func cheapHints() {
        var game = GameSession(puzzle: puzzle, scoring: .cheapHints)
        game.apply(game.hint()!)
        #expect(game.score == -3)
    }

    @Test func timeMultiplier() {
        let scoring = Scoring.standard
        #expect(scoring.timeMultiplierTenths(forSeconds: 0, difficulty: .easy) == 20)
        #expect(scoring.timeMultiplierTenths(forSeconds: 300, difficulty: .easy) == 20)
        #expect(scoring.timeMultiplierTenths(forSeconds: 600, difficulty: .easy) == 15)
        #expect(scoring.timeMultiplierTenths(forSeconds: 900, difficulty: .easy) == 10)
        #expect(scoring.timeMultiplierTenths(forSeconds: 5_000, difficulty: .easy) == 10)
        #expect(scoring.timeMultiplierTenths(forSeconds: 1_500, difficulty: .expert) == 20)
    }

    @Test func savesAndLoads() throws {
        var game = GameSession(mode: .daily(dayKey: "2026-11-02"), puzzle: puzzle)
        game.place(puzzle.solution[empty[0]], at: empty[0])
        game.toggleNote(4, at: empty[1])
        let data = try JSONEncoder().encode(game)
        let loaded = try JSONDecoder().decode(GameSession.self, from: data)
        #expect(loaded == game)
        // Small enough to save often.
        #expect(data.count < 20_000)
    }

    @Test func countPerDigit() {
        let game = GameSession(puzzle: puzzle)
        let total = (1...9).map(game.count(of:)).reduce(0, +)
        #expect(total == puzzle.clueCount)
    }
}

import Foundation

@Suite struct ProgressTests {
    func summary(difficulty: Difficulty = .easy, seconds: Int = 600, mistakes: Int = 1, hints: Int = 1, notes: Bool = true) -> WinSummary {
        WinSummary(score: 100, seconds: seconds, mistakes: mistakes, hintsUsed: hints, usedUndo: false, usedNotes: notes, difficulty: difficulty)
    }

    @Test func winAchievements() {
        var progress = PlayerProgress()
        var hits = progress.record(.won(summary(), isClassic: true))
        #expect(hits == [.firstWin])
        hits = progress.record(.won(summary(mistakes: 0), isClassic: true))
        #expect(hits == [.noMistakes])
        hits = progress.record(.won(summary(hints: 0), isClassic: true))
        #expect(hits == [.noHints])
        // Without notes only counts from medium up.
        hits = progress.record(.won(summary(notes: false), isClassic: true))
        #expect(hits == [])
        hits = progress.record(.won(summary(difficulty: .medium, notes: false), isClassic: true))
        #expect(hits == [.noNotes])
        hits = progress.record(.won(summary(difficulty: .expert), isClassic: true))
        #expect(hits == [.expert])
        hits = progress.record(.won(summary(seconds: 239), isClassic: true))
        #expect(hits == [.quick])
        #expect(progress.bestTime(.easy) == 239)
    }

    @Test func countedAchievements() {
        var progress = PlayerProgress()
        for _ in 0..<9 { _ = progress.record(.won(summary(), isClassic: true)) }
        var hits = progress.record(.won(summary(), isClassic: true))
        #expect(hits == [.tenWins])
        hits = progress.record(.dailyCompleted(currentStreak: 7, localHour: 2))
        #expect(hits == [.nightOwl, .consistency])
        hits = progress.record(.scoreChanged(-5))
        #expect(hits == [.inTheRed])
        #expect(progress.progress(of: .habit) == 7.0 / 30.0)
    }

    @Test func mergeKeepsTheBest() {
        var a = PlayerProgress(), b = PlayerProgress()
        _ = a.record(.won(summary(seconds: 500), isClassic: true))
        _ = b.record(.won(summary(seconds: 300), isClassic: true))
        _ = b.record(.won(summary(seconds: 400), isClassic: true))
        let merged = a.merged(with: b)
        #expect(merged.gamesWon == 2)
        #expect(merged.bestTime(.easy) == 300)
    }
}
