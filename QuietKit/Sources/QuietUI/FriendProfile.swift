#if canImport(UIKit)
@preconcurrency import GameKit
import QuietCore
import SwiftUI

// MARK: - Loading

/// A game's three boards, the same in every Quiet game: today's recurring daily, best
/// classic score and longest streak.
public struct FriendBoards: Sendable {
    public let daily: String
    public let best: String
    public let streak: String

    public init(daily: String, best: String, streak: String) {
        self.daily = daily
        self.best = best
        self.streak = streak
    }
}

/// The player and a friend side by side, with what Game Center gives: scores on the three
/// boards and the last days of the daily (its previous occurrences). Game Center doesn't
/// give other players' achievements, calendar or games. Shown only, never stored.
public struct HeadToHead: Sendable {
    public struct Matchup: Sendable {
        public let mine: GameCenterService.Entry?
        public let theirs: GameCenterService.Entry?

        public init(mine: GameCenterService.Entry?, theirs: GameCenterService.Entry?) {
            self.mine = mine
            self.theirs = theirs
        }

        /// Daily boards: higher score, then less time.
        public var result: DailyDuel.Result {
            DailyDuel.result(
                mine: mine.map { ($0.score, GameCenterService.dailySeconds(of: $0)) },
                theirs: theirs.map { ($0.score, GameCenterService.dailySeconds(of: $0)) }
            )
        }
    }

    public struct PastDaily: Identifiable, Sendable {
        /// When that day's board started.
        public let id: Date
        public let matchup: Matchup

        public init(start: Date, matchup: Matchup) {
            id = start
            self.matchup = matchup
        }
    }

    public let today: Matchup
    public let best: Matchup
    public let streak: Matchup
    /// Most recent first, today not included.
    public let past: [PastDaily]

    public init(today: Matchup, best: Matchup, streak: Matchup, past: [PastDaily]) {
        self.today = today
        self.best = best
        self.streak = streak
        self.past = past
    }

    /// Past days both played, and how many the player won.
    public var playedBoth: Int { past.filter { $0.matchup.result != .notBoth }.count }
    public var wins: Int { past.filter { $0.matchup.result == .won }.count }
}

/// The player wasn't on a board loaded this session.
struct UnknownPlayer: Error {}

public extension GameCenterService {
    /// Days of the daily compared in a profile.
    static let headToHeadDays = 7

    /// Loads the profile of a player seen on a board this session (friends tab, "Friends
    /// today"). Throws if Game Center doesn't answer.
    func headToHead(with playerID: String, boards: FriendBoards, days: Int = headToHeadDays) async throws -> HeadToHead {
        guard let friend = knownPlayers[playerID] else { throw UnknownPlayer() }
        let players: [GKPlayer] = [GKLocalPlayer.local, friend]
        let loaded = try await GKLeaderboard.loadLeaderboards(IDs: [boards.daily, boards.best, boards.streak])
        func board(_ id: String) -> GKLeaderboard? { loaded.first { $0.baseLeaderboardID == id } }

        func matchup(_ leaderboard: GKLeaderboard?) async throws -> HeadToHead.Matchup {
            guard let leaderboard else { return .init(mine: nil, theirs: nil) }
            let (local, entries) = try await leaderboard.loadEntries(for: players, timeScope: .allTime)
            let mine = (local ?? entries.first { $0.player.gamePlayerID == GKLocalPlayer.local.gamePlayerID })
            let theirs = entries.first { $0.player.gamePlayerID == playerID }
            return .init(mine: mine.map(Self.entry), theirs: theirs.map(Self.entry))
        }

        var past: [HeadToHead.PastDaily] = []
        var occurrence = board(boards.daily)
        for _ in 0..<days {
            guard let current = occurrence, let previous = try await current.loadPreviousOccurrence() else { break }
            past.append(.init(start: previous.startDate ?? .distantPast, matchup: try await matchup(previous)))
            occurrence = previous
        }
        return HeadToHead(
            today: try await matchup(board(boards.daily)),
            best: try await matchup(board(boards.best)),
            streak: try await matchup(board(boards.streak)),
            past: past
        )
    }

    /// The player's Game Center photo, if they have one.
    func photo(of playerID: String) async -> UIImage? {
        guard let player = knownPlayers[playerID] else { return nil }
        return try? await player.loadPhoto(for: .normal)
    }

    /// Game Center's own profile of the player (iOS 18+).
    func showProfile(of playerID: String) {
        guard let player = knownPlayers[playerID] else { return showDashboard() }
        GKAccessPoint.shared.trigger(player: player) {}
    }

    /// Today's daily among friends, ranked by score and time (`dailyEntries`), for the
    /// reminder's text. Nil when signed out or offline.
    func friendsToday(dailyID: String) async -> FriendsToday? {
        guard GKLocalPlayer.local.isAuthenticated,
              let top = try? await dailyEntries(for: dailyID, friendsOnly: true).top
        else { return nil }
        return FriendsToday(entries: top)
    }
}

public extension FriendsToday {
    /// From a friends board: the friends who played (not the player) and the best of them.
    init(entries: [GameCenterService.Entry]) {
        let friends = entries.filter { !$0.isLocalPlayer }
        self.init(count: friends.count, leaderName: friends.first?.name, leaderScore: friends.first?.score)
    }
}

// MARK: - Avatar

/// A player's photo, or their initial on a stable muted color.
public struct PlayerAvatar: View {
    let name: String
    let photo: UIImage?
    let size: CGFloat

    public init(name: String, photo: UIImage? = nil, size: CGFloat = 34) {
        self.name = name
        self.photo = photo
        self.size = size
    }

    public var body: some View {
        Group {
            if let photo {
                Image(uiImage: photo).resizable().scaledToFill()
            } else {
                Text(verbatim: String(name.prefix(1)).uppercased())
                    .font(.system(size: size * 0.42, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Self.color(for: name))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    /// FNV-1a, not `Hasher`, so a name keeps its color between launches.
    public static func color(for name: String) -> Color {
        Color(hue: Double(FNV1a.hash(name) % 360) / 360, saturation: 0.45, brightness: 0.55)
    }
}

/// "05:16", or "1:05:16" past an hour.
func clockText(_ seconds: Int) -> Text {
    let duration = Duration.seconds(seconds)
    return Text(seconds >= 3600
        ? duration.formatted(.time(pattern: .hourMinuteSecond))
        : duration.formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2))))
}

// MARK: - Friends today

/// Daily Challenge card: friends who already played today with score and time, and the
/// player's place among them. Tapping a friend opens their profile.
public struct FriendsTodayCard: View {
    /// Friends board of today's daily, already ranked by time (`dailyEntries`).
    let entries: [GameCenterService.Entry]
    let onSelect: (GameCenterService.Entry) -> Void

    @Environment(\.quietTheme) private var theme

    public init(entries: [GameCenterService.Entry], onSelect: @escaping (GameCenterService.Entry) -> Void) {
        self.entries = entries
        self.onSelect = onSelect
    }

    public var body: some View {
        let friends = entries.filter { !$0.isLocalPlayer }
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Friends today", bundle: .main)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(theme.ink)
                Spacer()
                if let me = entries.first(where: \.isLocalPlayer) {
                    Text("You're #\(me.rank)", bundle: .main)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(theme.primary)
                }
            }
            if friends.isEmpty {
                Text("None of your friends has played today's challenge yet.", bundle: .main)
                    .font(.footnote)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 0) {
                    ForEach(entries.prefix(6)) { entry in
                        row(entry)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background { SurfaceShape(shape: RoundedRectangle(cornerRadius: 24, style: .continuous)) }
    }

    @ViewBuilder
    private func row(_ entry: GameCenterService.Entry) -> some View {
        let content = HStack(spacing: 10) {
            Text(entry.rank, format: .number)
                .font(.footnote.weight(.heavy).monospacedDigit())
                .foregroundStyle(theme.muted)
                .frame(width: 22)
            PlayerAvatar(name: entry.name, size: 28)
            Text(verbatim: entry.name)
                .fontWeight(entry.isLocalPlayer ? .heavy : .regular)
                .foregroundStyle(entry.isLocalPlayer ? theme.primary : theme.ink)
                .lineLimit(1)
            Spacer(minLength: 6)
            if let seconds = GameCenterService.dailySeconds(of: entry) {
                clockText(seconds)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(theme.muted)
            }
            Text(entry.score, format: .number)
                .font(.system(.body, design: .rounded, weight: .heavy).monospacedDigit())
                .foregroundStyle(entry.isLocalPlayer ? theme.primary : theme.ink)
            if !entry.isLocalPlayer {
                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.muted)
            }
        }
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)

        if entry.isLocalPlayer {
            content
        } else {
            Button { onSelect(entry) } label: { content }
                .buttonStyle(.plain)
                .accessibilityIdentifier("friend-\(entry.name)")
        }
    }
}

// MARK: - Profile

/// A friend's profile: photo and name, then you and them side by side (today's daily,
/// best score, longest streak) and the last days of the daily ("You won 4 of 7").
public struct FriendProfileView: View {
    let name: String
    let load: @MainActor () async throws -> HeadToHead
    let loadPhoto: @MainActor () async -> UIImage?
    let onShowInGameCenter: (() -> Void)?

    @Environment(\.quietTheme) private var theme
    @State private var state: LoadState = .loading
    @State private var photo: UIImage?

    private enum LoadState {
        case loading
        case loaded(HeadToHead)
        case failed
    }

    /// `load` and `loadPhoto` usually call `GameCenterService.headToHead` and `photo(of:)`;
    /// demo launches pass fixed data.
    public init(
        name: String,
        load: @escaping @MainActor () async throws -> HeadToHead,
        loadPhoto: @escaping @MainActor () async -> UIImage? = { nil },
        onShowInGameCenter: (() -> Void)? = nil
    ) {
        self.name = name
        self.load = load
        self.loadPhoto = loadPhoto
        self.onShowInGameCenter = onShowInGameCenter
    }

    /// The usual case: a player from a board loaded this session.
    public init(entry: GameCenterService.Entry, gameCenter: GameCenterService, boards: FriendBoards) {
        self.init(
            name: entry.name,
            load: { try await gameCenter.headToHead(with: entry.id, boards: boards) },
            loadPhoto: { await gameCenter.photo(of: entry.id) },
            onShowInGameCenter: { gameCenter.showProfile(of: entry.id) }
        )
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                VStack(spacing: 10) {
                    PlayerAvatar(name: name, photo: photo, size: 84)
                    Text(verbatim: name)
                        .font(.system(.title2, design: .rounded, weight: .heavy))
                        .foregroundStyle(theme.ink)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                }
                .padding(.vertical, 8)

                switch state {
                case .loading:
                    ProgressView().padding(40)
                case .failed:
                    Text("Couldn't load this profile. Check your connection and try again.", bundle: .main)
                        .font(.subheadline)
                        .foregroundStyle(theme.muted)
                        .multilineTextAlignment(.center)
                        .padding(24)
                case .loaded(let duel):
                    sideBySide(duel)
                    pastDays(duel)
                }

                if let onShowInGameCenter {
                    Button(action: onShowInGameCenter) {
                        Text("View in Game Center", bundle: .main)
                    }
                    .buttonStyle(CapsuleButtonStyle(isProminent: false))
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .screen(Text(verbatim: name))
        .task {
            async let picture = loadPhoto()
            do {
                state = .loaded(try await load())
            } catch {
                state = .failed
            }
            photo = await picture
        }
    }

    // MARK: Side by side

    private func sideBySide(_ duel: HeadToHead) -> some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Text("You", bundle: .main).frame(width: 90)
                Text(verbatim: name).lineLimit(1).frame(width: 90)
            }
            .font(.footnote.weight(.bold))
            .foregroundStyle(theme.muted)
            .padding(.bottom, 4)
            row(Text("Today's challenge", bundle: .main), duel.today, showsTime: true)
            Divider().overlay(theme.separator)
            row(Text("Best score", bundle: .main), duel.best, showsTime: false)
            Divider().overlay(theme.separator)
            row(Text("Longest streak", bundle: .main), duel.streak, showsTime: false)
        }
        .padding(16)
        .background { SurfaceShape(shape: RoundedRectangle(cornerRadius: 24, style: .continuous)) }
    }

    private func row(_ title: Text, _ matchup: HeadToHead.Matchup, showsTime: Bool) -> some View {
        let result = showsTime ? matchup.result : DailyDuel.result(
            mine: matchup.mine.map { ($0.score, nil) }, theirs: matchup.theirs.map { ($0.score, nil) }
        )
        return HStack {
            title
                .font(.subheadline)
                .foregroundStyle(theme.ink)
            Spacer(minLength: 8)
            cell(matchup.mine, showsTime: showsTime, isAhead: result == .won)
            cell(matchup.theirs, showsTime: showsTime, isAhead: result == .lost)
        }
        .frame(minHeight: 52)
        .accessibilityElement(children: .combine)
    }

    private func cell(_ entry: GameCenterService.Entry?, showsTime: Bool, isAhead: Bool) -> some View {
        VStack(spacing: 1) {
            if let entry {
                Text(entry.score, format: .number)
                    .font(.system(.title3, design: .rounded, weight: isAhead ? .heavy : .medium).monospacedDigit())
                    .foregroundStyle(isAhead ? theme.primary : theme.ink)
                if showsTime, let seconds = GameCenterService.dailySeconds(of: entry) {
                    clockText(seconds)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(theme.muted)
                }
            } else {
                Text(verbatim: "–")
                    .font(.system(.title3, design: .rounded))
                    .foregroundStyle(theme.muted)
            }
        }
        .frame(width: 90)
    }

    // MARK: Last days

    private func pastDays(_ duel: HeadToHead) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Last \(GameCenterService.headToHeadDays) challenges", bundle: .main)
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(theme.ink)
                Spacer()
                if duel.playedBoth > 0 {
                    Text("You won \(duel.wins) of \(duel.playedBoth)", bundle: .main)
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(theme.primary)
                }
            }
            if duel.past.isEmpty {
                Text("No past challenges yet.", bundle: .main)
                    .font(.footnote)
                    .foregroundStyle(theme.muted)
            }
            ForEach(duel.past) { day in
                HStack(spacing: 10) {
                    Text(day.id, format: .dateTime.weekday(.abbreviated).day().month(.abbreviated))
                        .font(.footnote)
                        .foregroundStyle(theme.muted)
                    Spacer(minLength: 6)
                    // A tie on score is broken by time: show it.
                    let tied = day.matchup.mine?.score == day.matchup.theirs?.score
                    cell(day.matchup.mine, showsTime: tied, isAhead: day.matchup.result == .won)
                    cell(day.matchup.theirs, showsTime: tied, isAhead: day.matchup.result == .lost)
                }
                .frame(minHeight: 36)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(16)
        .background { SurfaceShape(shape: RoundedRectangle(cornerRadius: 24, style: .continuous)) }
    }
}
#endif
