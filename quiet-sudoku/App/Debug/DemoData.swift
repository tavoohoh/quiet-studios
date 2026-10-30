#if DEBUG
import Foundation
import QuietCore
import QuietSudokuCore
import QuietUI

/// `-demo`: a fixed, believable state for App Store screenshots, kept in memory only.
/// Saturday 2026-11-14 at 10:00 (a hard daily), a medium classic game a third of the way in, an
/// 8-day daily streak, several rewards unlocked, and sample leaderboards.
enum DemoData {
    static let isActive = ProcessInfo.processInfo.arguments.contains("-demo")

    static var date: Date? { isActive ? fixedDate : nil }

    private static let fixedDate = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 14, hour: 10))!

    private static let completedDays: [(day: String, score: Int)] =
        (20...30).map { ("2026-10-\($0)", 900 + $0 * 23) }
        + [("2026-11-02", 1_214), ("2026-11-03", 1_251)]
        + (6...13).map { (String(format: "2026-11-%02d", $0), 1_060 + $0 * 31) }

    static var progress: PlayerProgress {
        // `-unlockAll` too: the design captures show every style on the demo game.
        let unlocked: Set<Achievement> = ProcessInfo.processInfo.arguments.contains("-unlockAll")
            ? Set(Achievement.allCases)
            : [.firstWin, .noMistakes, .noHints, .tenWins, .consistency, .quick, .nightOwl]
        var progress = PlayerProgress(unlocked: unlocked)
        for index in completedDays.indices {
            _ = progress.record(.dailyCompleted(currentStreak: min(index + 1, 11), localHour: 20))
        }
        let summary = WinSummary(score: 1_480, seconds: 400, mistakes: 1, hintsUsed: 1, usedUndo: true, usedNotes: true, difficulty: .medium)
        for _ in 0..<41 { _ = progress.record(.won(summary, isClassic: true)) }
        for _ in 0..<24 { _ = progress.record(.abandoned(played: true)) }
        return progress
    }

    @MainActor
    static func seed(_ persistence: PersistenceService) {
        for (day, score) in completedDays {
            persistence.finishDaily(day, score: score, isCompleted: true)
        }
        // `-completeToday`: today's daily already won (reminders move to tomorrow).
        if ProcessInfo.processInfo.arguments.contains("-completeToday") {
            persistence.finishDaily("2026-11-14", score: 1_361, isCompleted: true, seconds: 268)
        }
        persistence.saveGame(classicGame, in: .classic)
    }

    /// A medium puzzle with a third of its empty cells filled (in the order a hint would)
    /// and a few notes. 6:12 on the clock.
    private static var classicGame: GameSession {
        let puzzle = Generator.puzzle(key: "quiet-demo", difficulty: .medium)
        var session = GameSession(puzzle: puzzle)
        let target = puzzle.givens.cells.count { $0 == 0 } / 3
        var placed = 0
        while placed < target, case .step(let step, _)? = session.hint(), let p = step.placement {
            session.place(p.digit, at: p.cell)
            placed += 1
        }
        let solver = LogicSolver(Grid(cells: session.values))
        for cell in (0..<81).filter({ session.values[$0] == 0 && solver.candidates[$0].nonzeroBitCount == 2 }).prefix(4) {
            for digit in Digits.list(solver.candidates[cell]) { session.toggleNote(digit, at: cell) }
        }
        for _ in 0..<372 { session.tick() }
        return session
    }

    /// Sample leaderboards (names from the Quiet Numbers canvas).
    static func leaderboard(_ board: Leaderboard) -> (local: GameCenterService.Entry?, top: [GameCenterService.Entry]) {
        let names = ["juli", "tatita12", "vale", "guss", "juanca", "cori16", "eliasb", "mariadelsea", "aleja", "nova47"]
        let scores: [Int] = switch board {
        case .daily: [1_412, 1_398, 1_377, 1_361, 1_340, 1_336, 1_333, 1_318, 1_296, 1_281]
        case .bestScore: [2_960, 2_811, 2_744, 2_480, 2_391, 2_350, 2_207, 2_166, 2_015, 1_980]
        case .longestStreak: [41, 33, 27, 19, 14, 12, 11, 9, 8, 6]
        }
        let top = zip(names, scores).enumerated().map { index, entry in
            GameCenterService.Entry(id: entry.0, rank: index + 1, name: entry.0, score: entry.1, isLocalPlayer: entry.0 == "guss")
        }
        return (top[3], top)
    }

    /// Today's friends board for "Friends today" (times in the context, like real scores).
    static var friendsToday: FriendsToday { FriendsToday(entries: friendsEntries) }

    static var friendsEntries: [GameCenterService.Entry] {
        let friends: [(String, Int, Int?)] = [("vale", 1_377, 251), ("guss", 1_361, 268), ("juanca", 1_361, 302), ("cori16", 1_296, 344)]
        let entries = friends.enumerated().map { index, friend in
            GameCenterService.Entry(id: friend.0, rank: index + 1, name: friend.0, score: friend.1, isLocalPlayer: friend.0 == "guss",
                                    context: GameCenterService.dailyContext(seconds: friend.2))
        }
        return GameCenterService.rankedByScoreAndTime(entries)
    }

    /// A friend's profile against the demo player: today, best, streak and the last 7 days.
    static func headToHead(with name: String) -> HeadToHead {
        func entry(_ score: Int, _ seconds: Int? = nil, mine: Bool) -> GameCenterService.Entry {
            GameCenterService.Entry(id: mine ? "guss" : name, rank: 0, name: mine ? "guss" : name, score: score,
                                    isLocalPlayer: mine, context: GameCenterService.dailyContext(seconds: seconds))
        }
        let days: [(Int, Int, Int?, Int?)] = [(1_340, 1_298, 280, 301), (1_212, 1_260, 330, 290), (1_401, 1_377, 255, 270),
                                              (1_190, 1_150, 360, 410), (1_305, 1_305, 262, 299), (980, 1_120, 520, 380), (1_288, 1_240, 300, 315)]
        let past = days.enumerated().map { index, day in
            HeadToHead.PastDaily(
                start: Calendar.current.date(byAdding: .day, value: -(index + 1), to: fixedDate)!,
                matchup: .init(mine: entry(day.0, day.2, mine: true), theirs: entry(day.1, day.3, mine: false))
            )
        }
        return HeadToHead(
            today: .init(mine: entry(1_361, 268, mine: true), theirs: entry(1_377, 251, mine: false)),
            best: .init(mine: entry(2_480, mine: true), theirs: entry(2_744, mine: false)),
            streak: .init(mine: entry(11, mine: true), theirs: entry(27, mine: false)),
            past: past
        )
    }

    /// `-demoClock <seconds>` presets the clock of a `-startGame` table.
    static var clock: Int {
        let arguments = ProcessInfo.processInfo.arguments
        guard let i = arguments.firstIndex(of: "-demoClock"), i + 1 < arguments.count else { return 0 }
        return Int(arguments[i + 1]) ?? 0
    }
}
#endif
