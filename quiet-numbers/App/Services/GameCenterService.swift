@preconcurrency import GameKit
import QuietNumbersCore

/// Optional Game Center layer. Everything works signed out; local data is the source
/// of truth and is pushed here when the player is authenticated.
/// GameKit itself retries submissions made while offline.
@MainActor
@Observable
final class GameCenterService {
    enum Leaderboard: String, CaseIterable {
        /// Recurring, resets every 24 h. Today's scored daily attempt.
        case daily = "daily_challenge"
        /// Classic: best classic score.
        case bestScore = "best_score"
        /// Classic: longest daily streak.
        case longestStreak = "longest_streak"
    }

    struct Entry: Identifiable {
        let id: String
        let rank: Int
        let name: String
        let score: Int
        let isLocalPlayer: Bool
    }

    /// Progress and daily results shared across the player's devices.
    struct Snapshot: Codable {
        var progress: PlayerProgress
        var dailies: [String: DailyRecord]
    }

    private(set) var isAuthenticated = false
    /// Called each time the player becomes authenticated, to sync pending data.
    var onAuthenticated: (() -> Void)?

    private static let savedGameName = "progress"

    /// Non-blocking: the game is fully playable while this runs or if it fails.
    /// Sign-in isn't forced on the player; they can sign in from system Settings.
    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] _, _ in
            Task { @MainActor in
                guard let self else { return }
                let authenticated = GKLocalPlayer.local.isAuthenticated
                let becameAuthenticated = authenticated && !self.isAuthenticated
                self.isAuthenticated = authenticated
                if becameAuthenticated { self.onAuthenticated?() }
            }
        }
    }

    // MARK: Achievements and scores

    func report(_ progress: PlayerProgress) async {
        guard isAuthenticated else { return }
        let achievements = Achievement.allCases.map { achievement in
            let reported = GKAchievement(identifier: achievement.gameCenterID)
            reported.percentComplete = progress.progress(of: achievement) * 100
            reported.showsCompletionBanner = true
            return reported
        }
        try? await GKAchievement.report(achievements)
    }

    func submit(_ score: Int, to leaderboard: Leaderboard) async {
        guard isAuthenticated, score > 0 else { return }
        try? await GKLeaderboard.submitScore(
            score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [leaderboard.rawValue]
        )
    }

    func entries(for leaderboard: Leaderboard, friendsOnly: Bool) async throws -> (local: Entry?, top: [Entry]) {
        guard let board = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboard.rawValue]).first else {
            return (nil, [])
        }
        let (local, entries, _) = try await board.loadEntries(
            for: friendsOnly ? .friendsOnly : .global,
            timeScope: .allTime,
            range: NSRange(1...25)
        )
        return (local.map(Self.entry), entries.map(Self.entry))
    }

    private static func entry(_ entry: GKLeaderboard.Entry) -> Entry {
        Entry(
            id: entry.player.gamePlayerID,
            rank: entry.rank,
            name: entry.player.displayName,
            score: entry.score,
            isLocalPlayer: entry.player.gamePlayerID == GKLocalPlayer.local.gamePlayerID
        )
    }

    // MARK: Saved games (iCloud)

    /// The snapshot stored in the player's iCloud, merging any conflicting copies.
    func fetchSnapshot() async -> Snapshot? {
        guard isAuthenticated,
              let games = try? await GKLocalPlayer.local.fetchSavedGames()
        else { return nil }
        let copies = games.filter { $0.name == Self.savedGameName }
        var snapshots: [Snapshot] = []
        for copy in copies {
            if let data = try? await copy.loadData(),
               let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
                snapshots.append(snapshot)
            }
        }
        guard var merged = snapshots.first else { return nil }
        for other in snapshots.dropFirst() {
            merged = merged.merged(with: other)
        }
        if copies.count > 1, let data = try? JSONEncoder().encode(merged) {
            _ = try? await GKLocalPlayer.local.resolveConflictingSavedGames(copies, with: data)
        }
        return merged
    }

    func save(_ snapshot: Snapshot) async {
        guard isAuthenticated, let data = try? JSONEncoder().encode(snapshot) else { return }
        _ = try? await GKLocalPlayer.local.saveGameData(data, withName: Self.savedGameName)
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
    /// Completed beats finished beats started; then the higher score.
    func better(than other: DailyRecord) -> DailyRecord {
        func rank(_ record: DailyRecord) -> (Int, Int) {
            (record.isCompleted ? 2 : record.isFinished ? 1 : 0, record.score)
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
