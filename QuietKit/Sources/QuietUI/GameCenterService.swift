#if canImport(UIKit)
@preconcurrency import GameKit
import OSLog
import UIKit

/// Optional Game Center layer, shared by the family. Everything works signed out; each
/// app's local data is the source of truth and is pushed here when the player is
/// authenticated. GameKit itself retries submissions made while offline.
///
/// Logs stay on the device (Console.app; in DEBUG also stdout). Nothing read from Game
/// Center is stored: names and scores are only shown (keeps "Data Not Collected").
@MainActor
@Observable
public final class GameCenterService {
    public struct Entry: Identifiable, Sendable {
        public let id: String
        public let rank: Int
        public let name: String
        public let score: Int
        public let isLocalPlayer: Bool

        public init(id: String, rank: Int, name: String, score: Int, isLocalPlayer: Bool) {
            self.id = id
            self.rank = rank
            self.name = name
            self.score = score
            self.isLocalPlayer = isLocalPlayer
        }
    }

    public private(set) var isAuthenticated = false
    /// The signed-in player's name, for Settings. Shown only, never stored.
    public private(set) var playerName: String?
    /// Called each time the player becomes authenticated, to sync pending data.
    public var onAuthenticated: (() -> Void)?

    /// GameKit's sign-in screen, kept until the player asks for it (never shown unprompted).
    private var signInController: UIViewController?
    private let savedGameName: String
    private let log: Logger

    /// `savedGameName`: the iCloud saved game that holds the app's snapshot.
    public init(subsystem: String, savedGameName: String = "progress") {
        self.savedGameName = savedGameName
        log = Logger(subsystem: subsystem, category: "GameCenter")
    }

    private func note(_ message: String, isError: Bool = false) {
        if isError { log.error("\(message, privacy: .public)") } else { log.info("\(message, privacy: .public)") }
        #if DEBUG
        print("[GameCenter] \(message)")
        #endif
    }

    /// Non-blocking: the game is fully playable while this runs or if it fails.
    /// Sign-in isn't forced on the player; they can sign in from system Settings.
    public func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { [weak self] controller, _ in
            Task { @MainActor in
                guard let self else { return }
                let authenticated = GKLocalPlayer.local.isAuthenticated
                let becameAuthenticated = authenticated && !self.isAuthenticated
                self.isAuthenticated = authenticated
                self.playerName = authenticated ? GKLocalPlayer.local.displayName : nil
                self.signInController = authenticated ? nil : controller
                if becameAuthenticated { self.onAuthenticated?() }
            }
        }
    }

    /// From "Open Settings" or the Game Center row: GameKit's sign-in if it offered one,
    /// otherwise the app's page in Settings.
    public func signIn() {
        let scene = UIApplication.shared.connectedScenes.first { $0.activationState == .foregroundActive } as? UIWindowScene
        if let controller = signInController, let root = scene?.keyWindow?.rootViewController {
            root.present(controller, animated: true)
        } else if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    /// Game Center's own dashboard (achievements, friends, profile).
    public func showDashboard() {
        GKAccessPoint.shared.trigger(state: .dashboard) {}
    }

    // MARK: Achievements and scores

    /// Percent complete (0...100) by achievement ID.
    public func report(_ percentages: [String: Double]) async {
        guard isAuthenticated else { return }
        let achievements = percentages.map { id, percent in
            let reported = GKAchievement(identifier: id)
            reported.percentComplete = percent
            reported.showsCompletionBanner = true
            return reported
        }
        do {
            try await GKAchievement.report(achievements)
        } catch {
            note("Reporting achievements failed: \(error)", isError: true)
        }
    }

    /// Recurring boards take every result (`always`, even zero or below); classic boards
    /// only take real records.
    public func submit(_ score: Int, to leaderboardID: String, always: Bool = false) async {
        guard isAuthenticated, always || score > 0 else { return }
        do {
            try await GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [leaderboardID])
            note("Submitted \(score) to \(leaderboardID)")
        } catch {
            note("Submitting \(score) to \(leaderboardID) failed: \(error)", isError: true)
        }
    }

    public func entries(for leaderboardID: String, friendsOnly: Bool) async throws -> (local: Entry?, top: [Entry]) {
        do {
            guard let board = try await GKLeaderboard.loadLeaderboards(IDs: [leaderboardID]).first else {
                note("Leaderboard \(leaderboardID) not found", isError: true)
                return (nil, [])
            }
            let (local, entries, total) = try await board.loadEntries(
                for: friendsOnly ? .friendsOnly : .global, timeScope: .allTime, range: NSRange(1...25)
            )
            note("\(leaderboardID): \(entries.count) of \(total) entries, local \(local?.score ?? -1)")
            // With no score on this board (or today's occurrence) yet, the local entry has rank 0.
            return (local.flatMap { $0.rank > 0 ? Self.entry($0) : nil }, entries.map(Self.entry))
        } catch {
            note("Loading \(leaderboardID) failed: \(error)", isError: true)
            throw error
        }
    }

    private static func entry(_ entry: GKLeaderboard.Entry) -> Entry {
        Entry(
            id: entry.player.gamePlayerID, rank: entry.rank, name: entry.player.displayName, score: entry.score,
            isLocalPlayer: entry.player.gamePlayerID == GKLocalPlayer.local.gamePlayerID
        )
    }

    // MARK: Saved games (iCloud)

    /// The snapshot stored in the player's iCloud. Conflicting copies are combined with
    /// `merge` (keep the most progress) and written back as one.
    public func fetchSnapshot<Snapshot: Codable>(_ type: Snapshot.Type, merge: (Snapshot, Snapshot) -> Snapshot) async -> Snapshot? {
        guard isAuthenticated, let games = try? await GKLocalPlayer.local.fetchSavedGames() else { return nil }
        let copies = games.filter { $0.name == savedGameName }
        var snapshots: [Snapshot] = []
        for copy in copies {
            if let data = try? await copy.loadData(), let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) {
                snapshots.append(snapshot)
            }
        }
        guard var merged = snapshots.first else { return nil }
        for other in snapshots.dropFirst() {
            merged = merge(merged, other)
        }
        if copies.count > 1, let data = try? JSONEncoder().encode(merged) {
            _ = try? await GKLocalPlayer.local.resolveConflictingSavedGames(copies, with: data)
        }
        return merged
    }

    public func save<Snapshot: Encodable>(_ snapshot: Snapshot) async {
        guard isAuthenticated, let data = try? JSONEncoder().encode(snapshot) else { return }
        _ = try? await GKLocalPlayer.local.saveGameData(data, withName: savedGameName)
    }

    /// Deletes the progress saved in iCloud and resets achievements. Leaderboard scores
    /// can't be withdrawn by the app; they stay until Game Center replaces or expires them.
    public func resetCloud() async -> Bool {
        guard isAuthenticated else { return false }
        do {
            try await GKLocalPlayer.local.deleteSavedGames(withName: savedGameName)
            try await GKAchievement.resetAchievements()
            return true
        } catch {
            return false
        }
    }
}
#endif
