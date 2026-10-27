import QuietSolitaireCore
import QuietUI
import SwiftUI

/// Interactive tutorial on the real board: each step rings the cards to move (like a hint),
/// explains the rule, and only that move counts (tap or drag). Shown before the first game
/// and from Settings › How to play. Nothing here counts for progress.
struct TutorialView: View {
    /// First run: ends by starting a game. From Settings: ends by going back.
    let isFirstRun: Bool
    let onFinish: () -> Void

    @State private var model = GameModel(session: GameSession(state: Tutorial.table), isTutorial: true)
    @State private var stepIndex = 0
    @State private var isFinished = false
    @State private var isAdvancing = false

    @Environment(\.quietTheme) private var theme
    @Environment(\.appearance) private var appearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// One per move in `Tutorial.moves`.
    private static let steps: [(title: LocalizedStringResource, text: LocalizedStringResource)] = [
        ("Turn a card", "Tap the stock to turn its top card over onto the waste."),
        ("Red on black", "Cards go on a column one rank lower and in the other color. Tap the 7♥ to put it on the 8♠."),
        ("Aces first", "Each suit builds up from its ace in the foundations at the top. Tap the A♦. The card under it turns over."),
        ("Move a run", "A run in order moves together. Tap the 8♠ to move it with the 7♥ onto the 9♥."),
        ("Keep building", "The 2♦ goes on the A♦. Foundations go up to the king."),
        ("Kings on empty columns", "Only a king goes on an empty column. Tap the K♣. You can also drag any card where you want it."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            Text("Step \(min(stepIndex + 1, Self.steps.count)) of \(Self.steps.count)")
                .font(.counter)
                .foregroundStyle(theme.muted)
                .padding(.top, 4)
            GeometryReader { geometry in
                BoardView(model: model, layout: BoardLayout(
                    size: geometry.size, maxWidth: Layout.boardWidth(sizeClass), leftHanded: appearance.leftHanded
                ))
            }
            .padding(.top, 14)
            explanation
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
        }
        .screen(Text("How to play")) {
            if !isFinished {
                Button("Skip", action: onFinish)
                    .font(.headline)
                    .foregroundStyle(theme.primary)
                    .frame(minWidth: 48, minHeight: 48)
                    .accessibilityIdentifier("skipTutorial")
            }
        }
        .onAppear { if model.guide == nil, !isFinished { guide(stepIndex) } }
        .onChange(of: model.session.moves) { advanceIfDone() }
    }

    @ViewBuilder
    private var explanation: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isFinished {
                Text("You're ready")
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(theme.ink)
                Text("Move every card to the foundations to win. Stuck? Undo, or ask for a hint for a few points.")
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                Button(isFirstRun ? "Start playing" : "Done", action: onFinish)
                    .buttonStyle(CapsuleButtonStyle())
                    .padding(.top, 6)
                    .accessibilityIdentifier("finishTutorial")
            } else {
                let step = Self.steps[stepIndex]
                Text(step.title)
                    .font(.system(.title3, design: .rounded, weight: .heavy))
                    .foregroundStyle(theme.ink)
                Text(step.text)
                    .foregroundStyle(theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .id(isFinished ? -1 : stepIndex)
        .transition(.opacity.combined(with: .offset(y: reduceMotion ? 0 : 8)))
        .accessibilityElement(children: .contain)
    }

    private func guide(_ index: Int) {
        model.setGuide(Tutorial.moves[index])
        AccessibilityNotification.Announcement(String(localized: Self.steps[index].text)).post()
    }

    /// After a step's move lands, point at the next one.
    private func advanceIfDone() {
        guard !isFinished, !isAdvancing, model.session.moves > stepIndex else { return }
        isAdvancing = true
        model.setGuide(nil)
        let next = stepIndex + 1
        Task {
            defer { isAdvancing = false }
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.2 : 0.6))
            withAnimation(.quiet) {
                if next < Tutorial.moves.count {
                    stepIndex = next
                    guide(next)
                } else {
                    isFinished = true
                }
            }
        }
    }
}
