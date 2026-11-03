import Foundation
import QuietNumbersCore
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

/// The scored attempt at one day's challenge.
@Model
final class StoredDaily {
    @Attribute(.unique) var dayKey: String
    var score: Int
    var isFinished: Bool
    /// The board was cleared. Only completed days count for the streak.
    var isCompleted: Bool
    var finishedAt: Date?
    /// Time played when it finished (leaderboard tie-break). `nil` before 1.1.
    var seconds: Int?

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

/// Read-only snapshot of a daily attempt for the UI.
struct DailyRecord: Equatable, Codable {
    let score: Int
    let isFinished: Bool
    let isCompleted: Bool
    /// Time played, once finished. Optional so older records and snapshots still load.
    var seconds: Int?
}

/// Local storage. SwiftData is the source of truth; Game Center only mirrors it.
@MainActor
@Observable
final class PersistenceService {
    enum Slot: Equatable {
        case classic
        /// Before 1.3, today's scored attempt (its day inside the session). Only read, to
        /// move it into its day's slot (`AppModel.moveLegacyDaily`).
        case legacyDaily
        /// The attempt in progress at one day's challenge, today or past (2026-11-02). A new
        /// attempt replaces it; it goes when the attempt ends or leaves the replay window.
        case day(String)

        /// "practice-" since 1.0, kept so games saved by older versions carry on.
        static let dayPrefix = "practice-"

        var rawValue: String {
            switch self {
            case .classic: "classic"
            case .legacyDaily: "daily"
            case .day(let dayKey): Self.dayPrefix + dayKey
            }
        }
    }

    private(set) var dailies: [String: DailyRecord] = [:]
    /// Days with an attempt saved halfway (for "Continue" and the calendar).
    private(set) var daysInProgress: Set<String> = []

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
        reloadDailies()
        reloadDaysInProgress()
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
        if case .day = slot { reloadDaysInProgress() }
    }

    func deleteGame(_ slot: Slot) {
        guard let stored = storedGame(slot) else { return }
        context.delete(stored)
        save()
        if case .day = slot { reloadDaysInProgress() }
    }

    /// Drops attempts left halfway on days that can no longer be played.
    func deleteDayGames(before oldestDayKey: String) {
        for game in dayGames() where game.slot.dropFirst(Slot.dayPrefix.count) < oldestDayKey {
            context.delete(game)
        }
        save()
        reloadDaysInProgress()
    }

    // MARK: Daily challenge

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

    /// A finished attempt: the day keeps the better of it and what it had (completed first,
    /// then score, then time; `DailyRecord.better`), today or past (2026-11-02).
    func keepBestDaily(_ dayKey: String, score: Int, isCompleted: Bool, seconds: Int) {
        let attempt = DailyRecord(score: score, isFinished: true, isCompleted: isCompleted, seconds: seconds)
        if let saved = dailies[dayKey], saved.better(than: attempt) == saved { return }
        finishDaily(dayKey, score: score, isCompleted: isCompleted, seconds: seconds)
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
        reloadDaysInProgress()
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
            ($0.dayKey, DailyRecord(score: $0.score, isFinished: $0.isFinished, isCompleted: $0.isCompleted, seconds: $0.seconds))
        })
    }

    private func dayGames() -> [StoredGame] {
        let prefix = Slot.dayPrefix
        return (try? context.fetch(FetchDescriptor<StoredGame>(predicate: #Predicate { $0.slot.starts(with: prefix) }))) ?? []
    }

    private func reloadDaysInProgress() {
        daysInProgress = Set(dayGames().map { String($0.slot.dropFirst(Slot.dayPrefix.count)) })
    }

    private func save() {
        try? context.save()
    }
}
