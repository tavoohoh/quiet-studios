import Foundation
import QuietSolitaireCore
import SwiftData

/// A game in progress, stored as the encoded `GameSession`.
@Model
final class StoredGame {
    @Attribute(.unique) var slot: String
    var data: Data
    var updatedAt: Date

    init(slot: String, data: Data, updatedAt: Date = .now) {
        self.slot = slot
        self.data = data
        self.updatedAt = updatedAt
    }
}

/// One day's challenge: its best result and how many attempts were started.
@Model
final class StoredDaily {
    @Attribute(.unique) var dayKey: String
    /// The best score of the day (the first attempt's before 1.0 (4)).
    var score: Int
    var isFinished: Bool
    /// The game was won. Only completed days count for the streak.
    var isCompleted: Bool
    var finishedAt: Date?
    /// Time played for `score` (leaderboard tie-break). `nil` before 1.0 (3).
    var seconds: Int?
    /// Attempts started (new deal or restart); after the first, a game is a replay.
    /// 0 before 1.0 (4), when only one attempt was tracked.
    var attempts: Int = 0

    init(dayKey: String) {
        self.dayKey = dayKey
        score = 0
        isFinished = false
        isCompleted = false
    }
}

/// Lifetime progress (`PlayerProgress`), stored as one encoded record.
@Model
final class StoredProgress {
    var data: Data

    init(data: Data) {
        self.data = data
    }
}

/// Read-only snapshot of a day's challenge for the UI.
struct DailyRecord: Equatable, Codable {
    let score: Int
    let isFinished: Bool
    let isCompleted: Bool
    /// Time played, once won. Optional so older records and snapshots still load.
    var seconds: Int?
    /// Local only (not in the Game Center snapshot).
    var attempts = 0

    private enum CodingKeys: String, CodingKey { case score, isFinished, isCompleted, seconds }
}

/// Local storage. SwiftData is the source of truth; Game Center only mirrors it.
@MainActor
@Observable
final class PersistenceService {
    enum Slot: Equatable {
        case classic
        /// The latest attempt at a day's challenge (today or past), kept until it's won,
        /// replaced by a new attempt, or the day leaves the replay window.
        case daily(dayKey: String)

        static let dailyPrefix = "daily-"

        var rawValue: String {
            switch self {
            case .classic: "classic"
            case .daily(let dayKey): Self.dailyPrefix + dayKey
            }
        }
    }

    private(set) var dailies: [String: DailyRecord] = [:]
    /// Days with a game saved halfway (for "Continue" and the calendar).
    private(set) var dailiesInProgress: Set<String> = []

    /// Kept alive for as long as `context` is used.
    private let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    enum Store {
        case standard
        case inMemory
        /// A separate file, so tests never touch the player's data.
        case named(String, reset: Bool)
    }

    init(store: Store = .standard) {
        let configuration: ModelConfiguration
        // Local only. With iCloud entitlements SwiftData would turn on CloudKit by default,
        // which this model doesn't support; progress syncs through Game Center saved games.
        switch store {
        case .standard:
            configuration = ModelConfiguration(cloudKitDatabase: .none)
        case .inMemory:
            configuration = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        case .named(let name, let reset):
            let url = URL.applicationSupportDirectory.appending(path: "\(name).store")
            if reset {
                for suffix in ["", "-shm", "-wal"] {
                    try? FileManager.default.removeItem(atPath: url.path(percentEncoded: false) + suffix)
                }
            }
            configuration = ModelConfiguration(url: url, cloudKitDatabase: .none)
        }
        // On a fresh install the folder may not exist yet; create it so the store opens cleanly.
        try? FileManager.default.createDirectory(at: .applicationSupportDirectory, withIntermediateDirectories: true)
        do {
            container = try ModelContainer(
                for: StoredGame.self, StoredDaily.self, StoredProgress.self,
                configurations: configuration
            )
        } catch {
            fatalError("Couldn't open the local store: \(error)")
        }
        migrateDailySlots()
        reloadDailies()
        reloadDailyGames()
    }

    var completedDays: Set<String> {
        Set(dailies.filter(\.value.isCompleted).keys)
    }

    // MARK: Games in progress

    func loadGame(_ slot: Slot) -> GameSession? {
        guard let stored = storedGame(slot) else { return nil }
        return try? JSONDecoder().decode(GameSession.self, from: stored.data)
    }

    func saveGame(_ session: GameSession, in slot: Slot) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        if let stored = storedGame(slot) {
            stored.data = data
            stored.updatedAt = .now
        } else {
            context.insert(StoredGame(slot: slot.rawValue, data: data))
        }
        save()
        if case .daily = slot { reloadDailyGames() }
    }

    func deleteGame(_ slot: Slot) {
        guard let stored = storedGame(slot) else { return }
        context.delete(stored)
        save()
        if case .daily = slot { reloadDailyGames() }
    }

    /// Drops saved games for days that can no longer be played.
    func deleteDailyGames(before oldestDayKey: String) {
        for game in dailyGames() where game.slot.dropFirst(Slot.dailyPrefix.count) < oldestDayKey {
            context.delete(game)
        }
        save()
        reloadDailyGames()
    }

    // MARK: Daily challenge

    /// Counts a new attempt at the day (a new deal or a restart).
    func startDaily(_ dayKey: String) {
        let stored = storedDaily(dayKey) ?? {
            let new = StoredDaily(dayKey: dayKey)
            context.insert(new)
            return new
        }()
        // Before 1.0 (4) only the first attempt was tracked.
        stored.attempts = max(stored.attempts, stored.isFinished ? 1 : 0) + 1
        save()
        reloadDailies()
    }

    /// A won attempt: the day counts as completed and keeps the better result (higher
    /// score, then faster). Returns whether the day was already completed.
    @discardableResult
    func winDaily(_ dayKey: String, score: Int, seconds: Int) -> Bool {
        let stored = storedDaily(dayKey) ?? {
            let new = StoredDaily(dayKey: dayKey)
            context.insert(new)
            return new
        }()
        let wasCompleted = stored.isCompleted
        let isFaster = seconds < stored.seconds ?? .max
        if !stored.isFinished || score > stored.score || (score == stored.score && isFaster) {
            stored.score = score
            stored.seconds = seconds
            stored.finishedAt = .now
        }
        stored.isFinished = true
        stored.isCompleted = true
        save()
        reloadDailies()
        return wasCompleted
    }

    func finishDaily(_ dayKey: String, score: Int, isCompleted: Bool, seconds: Int? = nil) {
        let stored = storedDaily(dayKey) ?? {
            let new = StoredDaily(dayKey: dayKey)
            context.insert(new)
            return new
        }()
        stored.score = score
        stored.isFinished = true
        stored.isCompleted = isCompleted
        stored.finishedAt = .now
        stored.seconds = seconds
        save()
        reloadDailies()
    }

    /// Adds daily results from another device, keeping the better result per day.
    func mergeDailies(_ remote: [String: DailyRecord]) {
        for (day, record) in remote {
            if let local = dailies[day], local.better(than: record) == local { continue }
            let stored = storedDaily(day) ?? {
                let new = StoredDaily(dayKey: day)
                context.insert(new)
                return new
            }()
            stored.score = record.score
            stored.isFinished = record.isFinished
            stored.isCompleted = record.isCompleted
            stored.seconds = record.seconds
        }
        save()
        reloadDailies()
    }

    // MARK: Progress

    func loadProgress() -> PlayerProgress {
        guard let stored = storedProgress else { return PlayerProgress() }
        return (try? JSONDecoder().decode(PlayerProgress.self, from: stored.data)) ?? PlayerProgress()
    }

    func saveProgress(_ progress: PlayerProgress) {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        if let stored = storedProgress {
            stored.data = data
        } else {
            context.insert(StoredProgress(data: data))
        }
        save()
    }

    // MARK: Private

    private var storedProgress: StoredProgress? {
        try? context.fetch(FetchDescriptor<StoredProgress>()).first
    }

    // MARK: Reset

    /// Deletes every game, daily result and the progress record.
    func deleteEverything() {
        try? context.delete(model: StoredGame.self)
        try? context.delete(model: StoredDaily.self)
        try? context.delete(model: StoredProgress.self)
        save()
        reloadDailies()
        reloadDailyGames()
    }

    private func storedGame(_ slot: Slot) -> StoredGame? {
        let key = slot.rawValue
        return try? context.fetch(FetchDescriptor<StoredGame>(predicate: #Predicate { $0.slot == key })).first
    }

    private func storedDaily(_ dayKey: String) -> StoredDaily? {
        try? context.fetch(FetchDescriptor<StoredDaily>(predicate: #Predicate { $0.dayKey == dayKey })).first
    }

    private func reloadDailies() {
        let all = (try? context.fetch(FetchDescriptor<StoredDaily>())) ?? []
        dailies = Dictionary(uniqueKeysWithValues: all.map {
            ($0.dayKey, DailyRecord(score: $0.score, isFinished: $0.isFinished, isCompleted: $0.isCompleted, seconds: $0.seconds, attempts: $0.attempts))
        })
    }

    private func dailyGames() -> [StoredGame] {
        let prefix = Slot.dailyPrefix
        return (try? context.fetch(FetchDescriptor<StoredGame>(predicate: #Predicate { $0.slot.starts(with: prefix) }))) ?? []
    }

    private func reloadDailyGames() {
        dailiesInProgress = Set(dailyGames().map { String($0.slot.dropFirst(Slot.dailyPrefix.count)) })
    }

    /// Before 1.0 (4): today's scored attempt lived in "daily" and replays in "practice-<day>".
    /// Each day keeps only its most recent game, in "daily-<day>".
    private func migrateDailySlots() {
        let all = (try? context.fetch(FetchDescriptor<StoredGame>())) ?? []
        let old = all.filter { $0.slot == "daily" || $0.slot.hasPrefix("practice-") }
        guard !old.isEmpty else { return }
        for game in old.sorted(by: { $0.updatedAt > $1.updatedAt }) {
            let dayKey: String? = if game.slot == "daily" {
                (try? JSONDecoder().decode(GameSession.self, from: game.data)).flatMap {
                    if case .daily(let key) = $0.mode { key } else { nil }
                }
            } else {
                String(game.slot.dropFirst("practice-".count))
            }
            let slot = dayKey.map { Slot.daily(dayKey: $0).rawValue }
            if let slot, !all.contains(where: { $0.slot == slot }) {
                game.slot = slot
            } else {
                context.delete(game)
            }
        }
        save()
    }

    private func save() {
        try? context.save()
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
