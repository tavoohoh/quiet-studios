import SwiftUI

/// Score, stage, and the + and hint counters. Nothing else.
struct GameTopBar: View {
    let model: GameModel
    let onAddNumbers: () -> Void
    let onHint: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.session.score, format: .number)
                    .font(.score)
                    .contentTransition(.numericText(value: Double(model.session.score)))
                    .accessibilityLabel(Text("Score"))
                    .accessibilityIdentifier("score")
                    .accessibilityValue(Text(model.session.score, format: .number))
                Text("Stage \(model.session.stage)")
                    .font(.counter)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            CounterButton(
                systemImage: "plus",
                count: model.session.plusRemaining,
                label: "Add numbers",
                isHighlighted: model.needsNumbers,
                action: onAddNumbers
            )
            .disabled(!model.canAddNumbers)
            .keyboardShortcut("+", modifiers: [])
            CounterButton(
                systemImage: "lightbulb",
                count: model.session.hintsRemaining,
                label: "Hint",
                isHighlighted: false,
                action: onHint
            )
            .disabled(!model.canUseHint)
            .keyboardShortcut("h", modifiers: [])
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

private struct CounterButton: View {
    let systemImage: String
    let count: Int
    let label: LocalizedStringKey
    let isHighlighted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.medium))
                    .symbolEffect(.pulse, options: .repeating, isActive: isHighlighted)
                Text(count, format: .number)
                    .font(.counter)
                    .contentTransition(.numericText(value: Double(count)))
            }
            .frame(width: 52, height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.tint)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text("\(count) remaining"))
    }
}
