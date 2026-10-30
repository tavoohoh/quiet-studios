import QuietCore
import QuietNumbersCore
import QuietUI

/// Quiet Numbers on the kit's `GameCenterService`: its leaderboards and achievement IDs,
/// and the snapshot it keeps in the player's iCloud.
extension GameCenterService {
    /// Logs under the app's subsystem; the saved game keeps the name it always had.
    static func quietNumbers() -> GameCenterService {
        GameCenterService(subsystem: "com.tavoohoh.quietnumbers", savedGameName: "progress")
    }

    enum Leaderboard: String, CaseIterable {
        /// Recurring, resets every 24 h. Today's scored daily attempt.
        case daily = "daily_challenge"
        /// Classic: best classic score.
        case bestScore = "best_score"
        /// Classic: longest daily streak.
        case longestStreak = "longest_streak"
    }

    /// Progress and daily results shared across the player's devices.
    struct Snapshot: Codable {
        var progress: PlayerProgress
        var dailies: [String: DailyRecord]
    }

    func report(_ progress: PlayerProgress) async {
        await report(Dictionary(uniqueKeysWithValues: Achievement.allCases.map {
            ($0.gameCenterID, progress.progress(of: $0) * 100)
        }))
    }

    /// Daily results are sent whatever they are (the board keeps the most recent one, even
    /// below zero); the classic boards only take real records.
    func submit(_ score: Int, to leaderboard: Leaderboard) async {
        await submit(score, to: leaderboard.rawValue, always: leaderboard == .daily)
    }

    /// Today's result, with its time as the score's context (0 = unknown, as from 1.0).
    func submitDaily(_ record: DailyRecord) async {
        await submit(record.score, to: Leaderboard.daily.rawValue, always: true, context: Self.dailyContext(seconds: record.seconds))
    }

    /// The daily board breaks ties by time, faster first (the kit's `dailyEntries`); Game
    /// Center itself only ranks by score.
    func entries(for leaderboard: Leaderboard, friendsOnly: Bool) async throws -> (local: Entry?, top: [Entry]) {
        leaderboard == .daily
            ? try await dailyEntries(for: leaderboard.rawValue, friendsOnly: friendsOnly)
            : try await entries(for: leaderboard.rawValue, friendsOnly: friendsOnly)
    }

    /// The three boards a friend's profile compares.
    static let friendBoards = FriendBoards(
        daily: Leaderboard.daily.rawValue, best: Leaderboard.bestScore.rawValue, streak: Leaderboard.longestStreak.rawValue
    )

    /// The snapshot stored in the player's iCloud, merging any conflicting copies.
    func fetchSnapshot() async -> Snapshot? {
        await fetchSnapshot(Snapshot.self) { $0.merged(with: $1) }
    }
}

extension GameCenterService.Snapshot {
    /// Keeps the most progress from both: counters and achievements via `PlayerProgress`,
    /// and per day the better daily result.
    func merged(with other: Self) -> Self {
        var dailies = self.dailies
        for (day, record) in other.dailies {
            dailies[day] = dailies[day].map { $0.better(than: record) } ?? record
        }
        return Self(progress: progress.merged(with: other.progress), dailies: dailies)
    }
}

extension DailyRecord {
    /// Completed beats finished beats started; then the higher score, then the faster time.
    func better(than other: DailyRecord) -> DailyRecord {
        func rank(_ record: DailyRecord) -> (Int, Int, Int) {
            (record.isCompleted ? 2 : record.isFinished ? 1 : 0, record.score, -(record.seconds ?? .max))
        }
        return rank(self) >= rank(other) ? self : other
    }
}

extension Achievement {
    /// Identifier configured in App Store Connect.
    var gameCenterID: String {
        switch self {
        case .firstStep: "first_step"
        case .cleanSlate: "clean_slate"
        case .noHelp: "no_help"
        case .inTheRed: "in_the_red"
        case .consistency: "consistency"
        case .habit: "habit"
        case .sweeper: "sweeper"
        case .stageFive: "stage_five"
        case .centennial: "centennial"
        case .nightOwl: "night_owl"
        case .monotone: "monotone"
        }
    }
}
