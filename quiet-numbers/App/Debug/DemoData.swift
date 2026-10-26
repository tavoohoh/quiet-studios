#if DEBUG
import Foundation
import QuietNumbersCore

/// `-demo`: a fixed, believable state for App Store screenshots, kept in memory only.
/// Saturday 2026-11-14 at 10:00, a classic game halfway through, an 8-day daily streak
/// (best 9), some rewards unlocked, and sample leaderboards.
enum DemoData {
    static let isActive = ProcessInfo.processInfo.arguments.contains("-demo")

    static var date: Date? { isActive ? fixedDate : nil }

    private static let fixedDate = Calendar.current.date(
        from: DateComponents(year: 2026, month: 11, day: 14, hour: 10)
    )!

    private static let completedDays: [(day: String, score: Int)] =
        (22...30).map { ("2026-10-\($0)", 180 + $0 * 7) }
        + [("2026-11-02", 214), ("2026-11-03", 251)]
        + (6...13).map { (String(format: "2026-11-%02d", $0), 160 + $0 * 11) }

    static var progress: PlayerProgress {
        var progress = PlayerProgress(unlocked: [
            .firstStep, .cleanSlate, .noHelp, .consistency, .stageFive, .nightOwl, .inTheRed,
        ])
        for (index, _) in completedDays.enumerated() {
            _ = progress.record(.dailyCompleted(currentStreak: min(index + 1, 9), localHour: 20))
        }
        _ = progress.record(.classicAbandoned(score: 2_480, played: true))
        return progress
    }

    @MainActor
    static func seed(_ persistence: PersistenceService) {
        for (day, score) in completedDays {
            persistence.finishDaily(day, score: score, isCompleted: true)
        }
        var session = GameSession(seed: FNV1a.hash("quiet-demo"))
        func play(_ moves: Int) {
            for move in 0..<moves {
                let pairs = MatchRules.validPairs(on: session.board)
                guard !pairs.isEmpty else { return }
                let pair = pairs[move.isMultiple(of: 2) ? 0 : pairs.count - 1]
                _ = session.match(at: pair.first, pair.second)
            }
        }
        // Some ghosts, one + (new numbers in the secondary color), a few more pairs.
        play(7)
        session.addNumbers()
        play(3)
        persistence.saveGame(session, in: .classic)
    }

    static func leaderboard(_ board: GameCenterService.Leaderboard) -> (local: GameCenterService.Entry?, top: [GameCenterService.Entry]) {
        let scores: [Int] = switch board {
        case .daily: [412, 398, 377, 361, 340, 336, 333, 318, 296, 281]
        case .bestScore: [6_120, 5_480, 4_905, 4_210, 3_870, 3_215, 2_990, 2_480, 2_310, 1_995]
        case .longestStreak: [212, 148, 96, 71, 64, 40, 33, 21, 12, 9]
        }
        let local = board == .bestScore ? 7 : board == .longestStreak ? 9 : 3
        // Same players as the App Store images (canvas page 3).
        var names = ["juli", "tatita12", "vale", "juanca", "cori16", "eliasb", "mariadelsea", "aleja", "nova47"]
        names.insert("guss", at: local)
        let top = zip(names.indices, scores).map { index, score in
            GameCenterService.Entry(
                id: "demo-\(index)", rank: index + 1, name: names[index],
                score: score, isLocalPlayer: index == local
            )
        }
        return (top[local], top)
    }
}
#endif
