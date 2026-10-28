#if DEBUG
import QuietCore
import Foundation
import QuietNumbersCore
import QuietUI

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
        _ = progress.record(.classicAbandoned(score: storeScene?.best ?? 2_480, played: true))
        return progress
    }

    @MainActor
    static func seed(_ persistence: PersistenceService) {
        for (day, score) in completedDays {
            persistence.finishDaily(day, score: score, isCompleted: true)
        }
        if let scene = storeScene {
            persistence.saveGame(scene.session, in: .classic)
            return
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

    // MARK: App Store images

    /// `-storeScene 1|2|4`: the hand-made board of the canvas's App Store images (Store1, 2
    /// and 4), so the real screenshot matches the approved frames and their callouts.
    struct StoreScene {
        let score: Int
        let stage: Int
        let best: Int

        /// Four original rows, then two rounds of + (from index 36). Every cleared pair is legal.
        static let rows = [
            [9, 7, 1, 7, 1, 9, 3, 5, 8],
            [2, 1, 9, 7, 4, 8, 8, 3, 8],
            [2, 8, 9, 4, 6, 5, 1, 5, 4],
            [5, 5, 8, 9, 1, 3, 7, 1, 1],
            [7, 1, 9, 3, 5, 4, 8, 8, 3],
            [8, 9, 4, 6, 5, 1, 5, 4, 5],
            [5, 8, 3, 7, 7, 1, 9, 3, 5],
            [4, 8, 8, 3, 8, 9, 5, 1, 5],
            [4, 8, 3, 7, 7, 9, 3, 4, 8],
            [8, 3, 4, 6, 1, 5, 4, 3, 7],
        ]
        static let ghosts: Set = [0, 2, 3, 8, 9, 10, 11, 12, 18, 19, 21, 22, 27, 28, 30, 31, 34, 35,
                                  37, 40, 45, 46, 47, 48, 49, 53, 54, 55, 64, 73]
        static let addedFrom = 36

        var session: GameSession {
            let cells = Self.rows.joined().enumerated().map { index, value in
                Cell(id: index, value: value, isCleared: Self.ghosts.contains(index), isAdded: index >= Self.addedFrom)
            }
            // Two + used on this board.
            return GameSession(board: Board(cells: cells), plusRemaining: GameSession.plusUses(forStage: stage) - 2,
                               stage: stage, score: score)
        }
    }

    static let storeScene: StoreScene? = {
        let arguments = ProcessInfo.processInfo.arguments
        guard isActive, let i = arguments.firstIndex(of: "-storeScene"), i + 1 < arguments.count else { return nil }
        return switch arguments[i + 1] {
        case "1": StoreScene(score: 1_240, stage: 2, best: 2_480)
        case "2": StoreScene(score: 3_385, stage: 3, best: 4_120)
        case "4": StoreScene(score: 9_615, stage: 5, best: 12_840)
        default: nil
        }
    }()

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
