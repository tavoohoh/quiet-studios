import QuietNumbersCore
import SwiftUI

/// Today's challenge, streaks, and the calendar of past days.
struct DailyChallengeView: View {
    let onPlay: (String) -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.appearance) private var appearance
    @State private var month = Date.now

    var body: some View {
        let today = app.todayKey
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 6) {
                    Text(DayKeyFormat.string(today, date: .long))
                        .font(.system(.title2, design: .rounded, weight: .semibold))
                    status(for: today)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 32) {
                    StatView(value: app.currentStreak, label: "Current streak")
                    StatView(value: app.longestStreak, label: "Best streak")
                }

                VStack(spacing: 8) {
                    Button {
                        onPlay(today)
                    } label: {
                        Text(playTitle(for: today)).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .buttonBorderShape(.capsule)
                    if !app.isScored(today) {
                        Text("Replays don't count toward your score.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: 360)

                CalendarView(month: $month, todayKey: today, records: app.persistence.dailies, onSelect: onPlay)
                    .frame(maxWidth: 420)

                Text("Next challenge in \(Text(DailyChallenge.nextRollover(after: .now), style: .relative))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .background(appearance.theme.background)
        .navigationTitle(Text("Daily Challenge"))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func status(for dayKey: String) -> Text {
        if app.isDailyInProgress(dayKey) { return Text("In progress") }
        guard let record = app.persistence.dailies[dayKey] else { return Text("Same board for everyone, today only.") }
        let score = Text(record.score, format: .number)
        return record.isCompleted ? Text("Completed · \(score)") : Text("Played · \(score)")
    }

    private func playTitle(for dayKey: String) -> LocalizedStringKey {
        if app.isDailyInProgress(dayKey) { return "Continue" }
        return app.isScored(dayKey) ? "Play" : "Play again"
    }
}

private struct StatView: View {
    let value: Int
    let label: LocalizedStringKey

    var body: some View {
        VStack(spacing: 2) {
            Text(value, format: .number)
                .font(.system(.title, design: .rounded, weight: .semibold).monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
