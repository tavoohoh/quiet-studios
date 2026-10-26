import QuietNumbersCore
import SwiftUI

/// Score and stage. Actions live in `GameActionBar`; praise and flying points in `GameFeedbackOverlay`.
struct GameTopBar: View {
    let model: GameModel
    /// Under the score: stage, or which daily this is.
    let subtitle: Text

    @Environment(\.appearance) private var appearance

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(model.displayedScore, format: .number)
                        .font(.score(design: appearance.numberFont.design))
                        .foregroundStyle(appearance.theme.ink)
                        .contentTransition(.numericText(value: Double(model.displayedScore)))
                        .anchorPreference(key: ScoreAnchorKey.self, value: .trailing) { $0 }
                        .accessibilityLabel(Text("Score"))
                        .accessibilityIdentifier("score")
                        .accessibilityValue(Text(model.session.score, format: .number))
                    ScoreChangeLabel(model: model)
                }
                subtitle
                    .font(.counter)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
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
        .padding(.horizontal)
        .padding(.vertical, 6)
    }
}

/// "+4" in the accent color (or "-3" muted) that rises and fades next to the score.
private struct ScoreChangeLabel: View {
    let model: GameModel

    var body: some View {
        ZStack {
            if let change = model.scoreChange {
                Text(change.amount, format: .number.sign(strategy: .always()))
                    .font(.system(.title3, design: .rounded, weight: .semibold).monospacedDigit())
                    .foregroundStyle(change.amount > 0 ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
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

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.medium))
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
        .foregroundStyle(.tint)
        .opacity(isEnabled ? 1 : 0.35)
        .accessibilityLabel(Text(label))
        .accessibilityValue(value)
    }
}
