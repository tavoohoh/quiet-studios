import QuietNumbersCore
import SwiftUI

/// Score and stage, with praise as a toast on the right. Actions live in `GameActionBar`;
/// points rise from the pair on the board (`FloatingPointsView`).
struct GameTopBar: View {
    let model: GameModel
    /// Under the score: stage and best, or which daily this is.
    let subtitle: Text

    @Environment(\.appearance) private var appearance
    @ScaledMetric(relativeTo: .largeTitle) private var scoreSize: CGFloat = 44

    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(model.displayedScore, format: .number)
                        .font(.score(size: min(scoreSize, 60), design: appearance.numberFont.design))
                        .foregroundStyle(appearance.theme.ink)
                        .contentTransition(.numericText(value: Double(model.displayedScore)))
                        .accessibilityLabel(Text("Score"))
                        .accessibilityIdentifier("score")
                        .accessibilityValue(Text(model.session.score, format: .number))
                    ScoreChangeLabel(model: model)
                }
                subtitle
                    .font(.counter)
                    .foregroundStyle(appearance.theme.muted)
            }
            Spacer(minLength: 0)
            ZStack {
                if let praise = model.praise {
                    PraiseToast(praise: praise) { model.dismissPraise(praise) }
                        .id(praise.id)
                }
            }
            .padding(.bottom, 6)
        }
        .padding(.horizontal, 24)
        .padding(.top, 14)
    }
}

/// Undo, + and hint, at the bottom within thumb reach.
struct GameActionBar: View {
    let model: GameModel
    let onUndo: () -> Void
    let onAddNumbers: () -> Void
    let onHint: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            CounterButton(
                systemImage: "arrow.uturn.backward",
                caption: Text("Undo"),
                label: "Undo",
                value: Text(verbatim: ""),
                isHighlighted: false,
                nudges: 0,
                action: onUndo
            )
            .disabled(!model.canUndo)
            .keyboardShortcut("z", modifiers: .command)
            CounterButton(
                systemImage: "plus",
                caption: Text(model.session.plusRemaining, format: .number),
                label: "Add numbers",
                value: Text("\(model.session.plusRemaining) remaining"),
                isHighlighted: model.needsNumbers,
                nudges: model.plusNudges,
                action: onAddNumbers
            )
            .disabled(!model.canAddNumbers)
            .keyboardShortcut("+", modifiers: [])
            CounterButton(
                systemImage: "lightbulb",
                caption: Text(-model.session.scoring.hintCost, format: .number),
                label: "Hint",
                value: Text("Costs \(model.session.scoring.hintCost) points"),
                isHighlighted: false,
                nudges: 0,
                action: onHint
            )
            .disabled(!model.canUseHint)
            .keyboardShortcut("h", modifiers: [])
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 6)
    }
}

/// "-3" (hints) or undone points next to the score; with Reduce Motion, match points too.
private struct ScoreChangeLabel: View {
    let model: GameModel

    @Environment(\.appearance) private var appearance

    var body: some View {
        ZStack {
            if let change = model.scoreChange {
                Text(change.amount, format: .number.sign(strategy: .always()))
                    .font(.system(.title3, design: .rounded, weight: .semibold).monospacedDigit())
                    .foregroundStyle(change.amount > 0 ? appearance.theme.primary : appearance.theme.muted)
                    .id(change.id)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 14)).combined(with: .scale(scale: 1.4)),
                        removal: .opacity.combined(with: .offset(y: -18))
                    ))
                    .task(id: change.id) {
                        try? await Task.sleep(for: .seconds(0.9))
                        withAnimation(.quiet) { model.dismissScoreChange(change) }
                    }
                    .accessibilityHidden(true)
            }
        }
    }
}

private struct CounterButton: View {
    let systemImage: String
    let caption: Text
    let label: LocalizedStringKey
    let value: Text
    let isHighlighted: Bool
    let nudges: Int
    let action: () -> Void

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.appearance) private var appearance

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 26, weight: .medium))
                    .symbolEffect(.pulse, options: .repeating, isActive: isHighlighted)
                    .symbolEffect(.bounce, options: .repeat(2), value: nudges)
                caption
                    .font(.counter)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(appearance.theme.primary)
        .opacity(isEnabled ? 1 : 0.35)
        .accessibilityLabel(Text(label))
        .accessibilityValue(value)
    }
}
