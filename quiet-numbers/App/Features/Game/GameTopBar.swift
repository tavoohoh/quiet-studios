import QuietNumbersCore
import SwiftUI

/// Score, stage, and the + and hint buttons, plus brief feedback after each move.
struct GameTopBar: View {
    let model: GameModel
    let onAddNumbers: () -> Void
    let onHint: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(model.session.score, format: .number)
                        .font(.score)
                        .contentTransition(.numericText(value: Double(model.session.score)))
                        .accessibilityLabel(Text("Score"))
                        .accessibilityIdentifier("score")
                        .accessibilityValue(Text(model.session.score, format: .number))
                    ScoreChangeLabel(model: model)
                }
                Text("Stage \(model.session.stage)")
                    .font(.counter)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            CounterButton(
                systemImage: "plus",
                caption: Text(model.session.plusRemaining, format: .number),
                label: "Add numbers",
                value: Text("\(model.session.plusRemaining) remaining"),
                isHighlighted: model.needsNumbers,
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
                action: onHint
            )
            .disabled(!model.canUseHint)
            .keyboardShortcut("h", modifiers: [])
        }
        .overlay { PraiseLabel(model: model) }
        .padding(.horizontal)
        .padding(.vertical, 8)
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
                        insertion: .opacity.combined(with: .offset(y: 10)),
                        removal: .opacity.combined(with: .offset(y: -14))
                    ))
                    .task(id: change.id) {
                        try? await Task.sleep(for: .seconds(1.2))
                        withAnimation(.quiet) { model.dismissScoreChange(change) }
                    }
                    .accessibilityHidden(true)
            }
        }
    }
}

/// "Long shot!", "Double row!"… centered in the bar for a moment.
private struct PraiseLabel: View {
    let model: GameModel

    var body: some View {
        ZStack {
            if let praise = model.praise {
                Text(praise.text)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(.tint)
                    .id(praise.id)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.8)),
                        removal: .opacity.combined(with: .offset(y: -10))
                    ))
                    .task(id: praise.id) {
                        AccessibilityNotification.Announcement(String(localized: praise.text)).post()
                        try? await Task.sleep(for: .seconds(1.6))
                        withAnimation(.quiet) { model.dismissPraise(praise) }
                    }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct CounterButton: View {
    let systemImage: String
    let caption: Text
    let label: LocalizedStringKey
    let value: Text
    let isHighlighted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.medium))
                    .symbolEffect(.pulse, options: .repeating, isActive: isHighlighted)
                caption
                    .font(.counter)
                    .contentTransition(.numericText())
            }
            .frame(width: 52, height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .accessibilityLabel(Text(label))
        .accessibilityValue(value)
    }
}
