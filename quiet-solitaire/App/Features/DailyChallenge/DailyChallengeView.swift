import QuietCore
import QuietSolitaireCore
import QuietUI
import SwiftUI

/// Today's challenge, streaks, and the calendar of past days.
struct DailyChallengeView: View {
    let onPlay: (String) -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.quietTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var month = AppClock.now
    /// Today's place among Game Center friends, when signed in.
    @State private var friendsRank: Int?

    var body: some View {
        let today = app.todayKey
        ScrollView {
            VStack(spacing: 12) {
                TodayCard(
                    date: Text(DayKeyFormat.weekdayString(today)),
                    status: status(for: today),
                    playTitle: playTitle(for: today),
                    showsReplayNote: !app.isScored(today),
                    streak: app.currentStreak,
                    bestStreak: app.longestStreak,
                    friendsRank: friendsRank,
                    onPlay: { onPlay(today) }
                )
                .disabled(app.isPreparing)

                WeekDifficulty(todayKey: today)

                VStack(spacing: 6) {
                    CalendarView(
                        month: $month, todayKey: today, records: app.persistence.dailies,
                        practiced: app.progress.practicedDays, onSelect: onPlay
                    )
                    Text("Next challenge in \(countdown)")
                        .font(.subheadline)
                        .foregroundStyle(theme.muted)
                        .padding(.top, 4)
                    Text("Past days are practice: they don't count toward your streak.")
                        .font(.footnote)
                        .foregroundStyle(theme.muted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 2)
                }
                .padding(.horizontal, 12)
                .padding(.top, 14)
                .padding(.bottom, 10)
                .background { SurfaceShape(shape: RoundedRectangle(cornerRadius: 26, style: .continuous)) }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: Layout.calendar(sizeClass) + 40)
            .frame(maxWidth: .infinity)
        }
        .screen(Text("Daily Challenge"))
        .task(id: app.gameCenter.isAuthenticated) { await loadFriendsRank() }
    }

    private func loadFriendsRank() async {
        guard app.gameCenter.isAuthenticated else { return friendsRank = nil }
        friendsRank = try? await app.gameCenter.entries(for: Leaderboard.daily.rawValue, friendsOnly: true).local?.rank
    }

        private var countdown: Text {
        Text(DailyKey.nextRollover(after: AppClock.now), style: .relative)
    }

    private func status(for dayKey: String) -> Text {
        if app.isDailyInProgress(dayKey) { return Text("In progress") }
        guard let record = app.persistence.dailies[dayKey] else { return Text("Not played yet") }
        return Text("Won · \(Text(record.score, format: .number))")
    }

    private func playTitle(for dayKey: String) -> LocalizedStringKey {
        if app.isDailyInProgress(dayKey) { return "Continue" }
        return app.isScored(dayKey) ? "Play" : "Play again"
    }
}

/// Today in `primary`: date, status, the play button and three small stats.
private struct TodayCard: View {
    let date: Text
    let status: Text
    let playTitle: LocalizedStringKey
    let showsReplayNote: Bool
    let streak: Int
    let bestStreak: Int
    let friendsRank: Int?
    let onPlay: () -> Void

    @Environment(\.quietTheme) private var theme

    var body: some View {
        let onPrimary = theme.onPrimary
        VStack(alignment: .leading, spacing: 14) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    heading
                    Spacer(minLength: 0)
                    playButton
                }
                VStack(alignment: .leading, spacing: 12) {
                    heading
                    playButton
                }
            }
            HStack(spacing: 8) {
                StatTile(label: "Streak", showsFlame: true) { Text(streak, format: .number) }
                StatTile(label: "Best streak") { Text(bestStreak, format: .number) }
                StatTile(label: "Friends") {
                    if let friendsRank { Text(verbatim: "#") + Text(friendsRank, format: .number) } else { Text(verbatim: "–") }
                }
            }
            if showsReplayNote {
                Text("Replays don't count toward your score.")
                    .font(.footnote)
                    .foregroundStyle(onPrimary.opacity(0.85))
            }
        }
        .padding(18)
        .background(theme.primary, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 2) {
            date
                .font(.subheadline)
                .foregroundStyle(theme.onPrimary.opacity(0.85))
            status
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundStyle(theme.onPrimary)
        }
        .accessibilityElement(children: .combine)
    }

    private var playButton: some View {
        Button(playTitle, action: onPlay)
            .buttonStyle(AccentButtonStyle())
    }
}

private struct StatTile<Value: View>: View {
    let label: LocalizedStringKey
    var showsFlame = false
    @ViewBuilder let value: Value

    @Environment(\.quietTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                if showsFlame {
                    Image(systemName: "flame.fill")
                        .font(.subheadline)
                        .foregroundStyle(theme.onPrimary.opacity(0.85))
                }
                value
                    .font(.stat)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Text(label)
                .font(.footnote)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .opacity(0.85)
        }
        .foregroundStyle(theme.onPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(theme.onPrimary.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// The week's difficulty: a bar per weekday, today's in `primary`.
private struct WeekDifficulty: View {
    let todayKey: String

    @Environment(\.quietTheme) private var theme

    var body: some View {
        let today = DailyKey.weekday(ofDayKey: todayKey) ?? 1
        let difficulty = Difficulty.forWeekday(today)
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("This week")
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(theme.ink)
                Spacer()
                Text("Today: \(Text(difficulty.title))")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(theme.primary)
            }
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(1...7, id: \.self) { weekday in
                    let level = Difficulty.forWeekday(weekday).rawValue + 1
                    let isToday = weekday == today
                    VStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(isToday ? theme.primary : theme.primary.opacity(0.2))
                            .frame(width: 22, height: CGFloat(6 + level * 7))
                            .frame(height: 36, alignment: .bottom)
                        Text(Self.symbols[weekday - 1])
                            .font(.caption.weight(.bold))
                            .foregroundStyle(isToday ? theme.primary : theme.muted)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Monday and Tuesday easy, Wednesday to Friday medium, Saturday hard, Sunday expert."))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background { SurfaceShape(shape: RoundedRectangle(cornerRadius: 24, style: .continuous)) }
    }

    /// Monday first, in the device's language.
    private static var symbols: [String] {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        return Array(symbols[1...] + symbols[..<1]).map { $0.uppercased() }
    }
}
