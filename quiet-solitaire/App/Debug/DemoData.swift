#if DEBUG
import Foundation
import QuietCore
import QuietSolitaireCore
import QuietUI

/// `-demo`: a fixed, believable state for App Store screenshots, kept in memory only.
/// Saturday 2026-11-14 at 10:00 (a hard daily), a classic game a third of the way in, an
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
        // `-unlockAll` too: the design captures show every deck on the demo game.
        let unlocked: Set<Achievement> = ProcessInfo.processInfo.arguments.contains("-unlockAll")
            ? Set(Achievement.allCases)
            : [.firstWin, .noUndo, .noHints, .onePass, .tenWins, .consistency, .ladder, .economy, .nightOwl]
        var progress = PlayerProgress(unlocked: unlocked)
        for index in completedDays.indices {
            _ = progress.record(.dailyCompleted(currentStreak: min(index + 1, 11), localHour: 20))
        }
        let summary = WinSummary(score: 1_480, moves: 128, usedUndo: true, hintsUsed: 1, recycles: 2, seconds: 400)
        for _ in 0..<41 { _ = progress.record(.won(summary, isClassic: true)) }
        for _ in 0..<24 { _ = progress.record(.abandoned(played: true)) }
        _ = progress.record(.classicScore(2_480))
        return progress
    }

    @MainActor
    static func seed(_ persistence: PersistenceService) {
        for (day, score) in completedDays {
            persistence.finishDaily(day, score: score, isCompleted: true)
        }
        persistence.saveGame(classicGame, in: .classic)
    }

    /// A winnable deal played forward by the solver until about a fifth of the cards are
    /// home: foundations started, runs built, cards still face down. 3:16 on the clock.
    private static var classicGame: GameSession {
        var session = GameSession(seed: Deals.winnableSeed(startingAt: FNV1a.hash("quiet-demo")))
        while session.state.foundations.reduce(0, { $0 + $1.count }) < 11, session.moves < 160,
              let move = GameSession.suggestion(for: session.state) {
            session.play(move)
        }
        for _ in 0..<196 { session.tick() }
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

    /// `-demoClock <seconds>` presets the clock of a `-startGame` table.
    static var clock: Int {
        let arguments = ProcessInfo.processInfo.arguments
        guard let i = arguments.firstIndex(of: "-demoClock"), i + 1 < arguments.count else { return 0 }
        return Int(arguments[i + 1]) ?? 0
    }
}
#endif
