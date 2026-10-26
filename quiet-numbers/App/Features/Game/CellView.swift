import QuietNumbersCore
import SwiftUI

struct CellView: View {
    let cell: Cell
    let row: Int
    let column: Int
    let size: CGSize
    let isSelected: Bool
    /// Part of an invalid pair: ringed in the accent color for a moment.
    let isMissed: Bool
    let isHinted: Bool
    let shakes: Int
    /// Set for numbers just added with +: they scale and fade in after this delay.
    let entranceDelay: Double?
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appearance) private var appearance
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var hasEntered = false

    var body: some View {
        Button(action: action) {
            Text(verbatim: "\(cell.value)")
                .font(.boardNumber(size: size.height * numberScale, design: appearance.numberFont.design))
                .foregroundStyle(numberColor)
                .underline(cell.isAdded && !cell.isCleared && appearance.theme.isHighContrast, color: appearance.theme.accent)
                .frame(width: size.width, height: size.height)
                .background { tile }
                .background { ring }
                .overlay {
                    if isHinted {
                        HintRing(diameter: ringDiameter)
                            .transition(.opacity)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(cell.isCleared)
        .modifier(ShakeEffect(shakes: reduceMotion ? 0 : CGFloat(shakes)))
        .animation(.linear(duration: 0.24 * EffectTiming.scale), value: shakes)
        .scaleEffect(hasEntered || entranceDelay == nil || reduceMotion ? 1 : 0.8)
        .opacity(hasEntered || entranceDelay == nil ? 1 : 0)
        .onAppear {
            guard let entranceDelay, !hasEntered else { return }
            withAnimation(.easeOut(duration: 0.16 * EffectTiming.scale).delay(entranceDelay)) { hasEntered = true }
        }
        .accessibilityLabel(Text("\(cell.value), row \(row + 1), column \(column + 1)"))
        .accessibilityValue(cell.isCleared ? Text("Cleared") : Text(verbatim: ""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("cell-\(row * Board.columns + column)")
    }
}

extension CellView {
    /// Board numbers are sized by the row, not Dynamic Type (9 columns must fit):
    /// 27 pt on a 46 pt row, 32 pt on the 52 pt row of "Larger numbers".
    private var numberScale: CGFloat {
        appearance.largerNumbers || dynamicTypeSize.isAccessibilitySize ? 32 / 52 : 27 / 46
    }

    /// 40 pt on a 46 pt row.
    private var ringDiameter: CGFloat { size.height * 40 / 46 }

    /// Selection (primary) or a missed pair (accent): a 2 pt ring over a 14% fill.
    @ViewBuilder
    private var ring: some View {
        if isSelected || isMissed {
            let color = isMissed ? appearance.theme.accent : appearance.theme.primary
            Circle()
                .fill(color.opacity(0.14))
                .strokeBorder(color, lineWidth: 2)
                .frame(width: ringDiameter, height: ringDiameter)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.6)))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
    }

    /// Tile style from the Collection. Ghosts never get a tile.
    @ViewBuilder
    private var tile: some View {
        if !cell.isCleared {
            switch appearance.tileStyle {
            case .plain:
                EmptyView()
            case .circle:
                Circle().fill(appearance.theme.ink.opacity(0.07)).frame(width: ringDiameter, height: ringDiameter)
            case .outline:
                Circle().strokeBorder(appearance.theme.ink.opacity(0.25), lineWidth: 1)
                    .frame(width: ringDiameter - 4, height: ringDiameter - 4)
            }
        }
    }

    /// Ghosts stay faintly visible; numbers added with + use the accent so the originals stand out.
    private var numberColor: Color {
        if cell.isCleared { return appearance.theme.ghost }
        if isMissed { return appearance.theme.accent }
        if isSelected { return appearance.theme.primary }
        return cell.isAdded ? appearance.theme.accent : appearance.theme.ink
    }
}

/// Dashed ring on a hinted pair; blinks twice, then stays.
private struct HintRing: View {
    let diameter: CGFloat

    @Environment(\.appearance) private var appearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var blinks = 0

    var body: some View {
        Circle()
            .strokeBorder(appearance.theme.primary, style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
            .frame(width: diameter, height: diameter)
            .keyframeAnimator(initialValue: 1.0, trigger: blinks) { content, opacity in
                content.opacity(opacity)
            } keyframes: { _ in
                let half = 0.25 * EffectTiming.scale
                LinearKeyframe(0.2, duration: half)
                LinearKeyframe(1, duration: half)
                LinearKeyframe(0.2, duration: half)
                LinearKeyframe(1, duration: half)
            }
            .onAppear { if !reduceMotion { blinks += 1 } }
    }
}

/// Small horizontal shake: ±4 pt, three times. Animating `shakes` from n to n + 1 plays one.
struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 4 * sin(shakes * .pi * 6), y: 0))
    }
}
