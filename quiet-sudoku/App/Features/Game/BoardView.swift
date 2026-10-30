import QuietSudokuCore
import QuietUI
import SwiftUI

/// The 9×9 grid: thin lines between cells, thick ones between boxes; givens in ink, the
/// player's digits in the primary color, mistakes in the accent, notes small in a 3×3.
struct BoardView: View {
    let model: GameModel
    let size: CGFloat

    @Environment(\.quietTheme) private var theme
    @Environment(\.appearance) private var appearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Bumped on a win: the wave runs from the last digit outwards.
    @State private var wave = 0
    @State private var waveOrigin = 40

    private var cell: CGFloat { size / 9 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(theme.surface)
            ForEach(0..<81, id: \.self) { index in
                CellView(model: model, index: index, size: cell, wave: wave, waveDelay: waveDelay(index))
                    .offset(x: CGFloat(Grid.column(of: index)) * cell, y: CGFloat(Grid.row(of: index)) * cell)
            }
            lines
                .allowsHitTesting(false)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(theme.ink, lineWidth: 2)
        }
        .onChange(of: model.session.isWon) { _, won in
            guard won, appearance.victory == .wave, !reduceMotion else { return }
            waveOrigin = model.selected ?? 40
            wave += 1
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Board"))
    }

    private func waveDelay(_ index: Int) -> Double {
        let dr = Double(Grid.row(of: index) - Grid.row(of: waveOrigin))
        let dc = Double(Grid.column(of: index) - Grid.column(of: waveOrigin))
        return (dr * dr + dc * dc).squareRoot() * 0.06
    }

    private var lines: some View {
        Canvas { context, canvasSize in
            let step = canvasSize.width / 9
            for i in 1..<9 {
                let thick = i % 3 == 0
                let position = CGFloat(i) * step
                var path = Path()
                path.move(to: CGPoint(x: position, y: 0))
                path.addLine(to: CGPoint(x: position, y: canvasSize.height))
                path.move(to: CGPoint(x: 0, y: position))
                path.addLine(to: CGPoint(x: canvasSize.width, y: position))
                context.stroke(path, with: .color(thick ? theme.ink : theme.separator), lineWidth: thick ? 2 : 1)
            }
        }
    }
}

/// One cell: its fill (selection, peers, same digit, hint, flash), the digit or the notes.
private struct CellView: View {
    let model: GameModel
    let index: Int
    let size: CGFloat
    let wave: Int
    let waveDelay: Double

    @Environment(\.quietTheme) private var theme
    @Environment(\.appearance) private var appearance

    private var session: GameSession { model.session }
    private var value: Int { session.values[index] }

    var body: some View {
        ZStack {
            Rectangle().fill(fill)
            if value != 0 {
                Text(verbatim: "\(value)")
                    .font(appearance.digits.font(size: size * (appearance.largeDigits ? 0.72 : 0.6), weight: session.isGiven(index) ? .semibold : .regular))
                    .foregroundStyle(digitColor)
                    // Not by color alone: a wrong digit is also underlined.
                    .underline(model.showsWrong(index), color: theme.accent)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            } else if session.notes[index] != 0 {
                notes
            }
            if isHintClue {
                Circle()
                    .strokeBorder(theme.accent, style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                    .padding(size * 0.08)
            }
        }
        .frame(width: size, height: size)
        .modifier(Shake(amount: model.shaking == index ? 1 : 0))
        .animation(.linear(duration: 0.3), value: model.shaking == index)
        .keyframeAnimator(initialValue: 1.0, trigger: wave) { content, scale in
            content.scaleEffect(scale).zIndex(scale > 1 ? 1 : 0)
        } keyframes: { _ in
            LinearKeyframe(1.0, duration: waveDelay)
            SpringKeyframe(1.18, duration: 0.16)
            SpringKeyframe(1.0, duration: 0.3)
        }
        .contentShape(Rectangle())
        .onTapGesture { model.select(index) }
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(model.selected == index ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { model.select(index) }
        .accessibilityIdentifier("cell-\(index)")
    }

    private var notes: some View {
        let mask = session.notes[index]
        let noteSize = size / 3
        return VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(1...3, id: \.self) { column in
                        let digit = row * 3 + column
                        Text(verbatim: mask & Digits.bit(digit) != 0 ? "\(digit)" : " ")
                            .font(.system(size: noteSize * (appearance.largeDigits ? 0.78 : 0.66), weight: noteWeight(digit), design: .rounded))
                            .foregroundStyle(noteColor(digit))
                            .frame(width: noteSize, height: noteSize)
                    }
                }
            }
        }
    }

    private func noteWeight(_ digit: Int) -> Font.Weight {
        model.selectedDigit == digit ? .heavy : .medium
    }

    private func noteColor(_ digit: Int) -> Color {
        if model.selectedDigit == digit { return theme.primary }
        return appearance.notes == .colored ? theme.accent : theme.muted
    }

    private var digitColor: Color {
        if model.showsWrong(index) { return theme.accent }
        return session.isGiven(index) ? theme.ink : theme.primary
    }

    private var fill: Color {
        if model.showsWrong(index) { return theme.accent.opacity(0.16) }
        if model.selected == index { return theme.primary.opacity(0.3) }
        if model.flashing.contains(where: { Grid.unitsOfCell[index].contains($0) }) { return theme.primary.opacity(0.22) }
        if let digit = model.selectedDigit, value == digit { return theme.primary.opacity(0.16) }
        if isInHintUnit { return theme.accent.opacity(0.08) }
        if appearance.highlight == .full, let selected = model.selected, Grid.sees(selected, index) { return theme.surface2 }
        return .clear
    }

    private var isInHintUnit: Bool {
        if let guide = model.guide { return guide.units.contains { Grid.unitsOfCell[index].contains($0) } }
        guard case .step(let step, _)? = model.hint else { return false }
        return step.units.contains { Grid.unitsOfCell[index].contains($0) }
    }

    private var isHintClue: Bool {
        if let guide = model.guide { return guide.clues.contains(index) }
        guard case .step(let step, _)? = model.hint else { return false }
        return step.cells.contains(index) && step.placement?.cell != index
    }

    private var accessibilityText: Text {
        let row = Grid.row(of: index) + 1, column = Grid.column(of: index) + 1
        if value != 0 {
            if model.showsWrong(index) { return Text("Row \(row), column \(column), \(value), wrong") }
            return Text("Row \(row), column \(column), \(value)")
        }
        let notes = Digits.list(session.notes[index])
        if notes.isEmpty { return Text("Row \(row), column \(column), empty") }
        return Text("Row \(row), column \(column), empty, notes \(notes.map(String.init).formatted(.list(type: .and)))")
    }
}

/// ±4 pt three times.
private struct Shake: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 4 * sin(amount * .pi * 6), y: 0))
    }
}
