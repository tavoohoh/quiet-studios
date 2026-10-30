import Testing
@testable import QuietSudokuCore
import QuietCore

@Suite struct DailyTests {
    /// Reference boards: the same date gives the same puzzle on every device and version.
    /// Changing the generator, the solver or the technique order changes them: only on purpose.
    static let reference: [(day: String, givens: String)] = [
        ("2026-11-02", "2...9.....1.67.2.3.47..36.5.361..7.9.7.....3.1.2..746.7.12..38.3.4.69.2.....1...7"),
        ("2026-11-04", "....7...937..46..5.96.1..8.......27.6.......1.34.......4..2.85.2..39..178...5...."),
        ("2026-11-07", "...57...2..9..6.....5..3..1..4....6.26.4.1.53.8....1..6..8..9.....6..4..4...37..."),
        ("2026-11-08", "...........46.7.3..5..428..7.....6.85......411.8.....7..34...5..6.1..4.....9....."),
    ]

    @Test func sameDateSamePuzzle() {
        for (day, givens) in Self.reference {
            #expect(DailyChallenge.puzzle(forDayKey: day).givens.string == givens, "\(day)")
        }
    }

    @Test func difficultyByWeekday() {
        // 2026-11-02 is a Monday.
        let expected: [Difficulty] = [.easy, .easy, .medium, .medium, .medium, .hard, .expert]
        for (offset, difficulty) in expected.enumerated() {
            #expect(DailyChallenge.difficulty(forDayKey: DailyKey.dayKey("2026-11-02", addingDays: offset)!) == difficulty)
        }
    }

    @Test func dailySession() {
        let session = DailyChallenge.session(forDayKey: "2026-11-08")
        #expect(session.mode == .daily(dayKey: "2026-11-08"))
        #expect(session.difficulty == .expert)
        #expect(session.scoring.hint == 10)
    }

    /// A whole year of dailies: unique, and the day's level by technique. Slow in debug:
    /// run with `swift test -c release`.
    @Test func aYearOfDailies() {
        var day = "2026-11-01"
        for _ in 0..<365 {
            let puzzle = DailyChallenge.puzzle(forDayKey: day)
            check(puzzle, DailyChallenge.difficulty(forDayKey: day))
            day = DailyKey.dayKey(day, addingDays: 1)!
        }
    }
}
