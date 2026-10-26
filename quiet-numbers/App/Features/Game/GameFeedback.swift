import SwiftUI

/// "+4": appears at the middle of the matched pair, rises 24 pt and fades.
struct FloatingPointsView: View {
    let points: FloatingPoints
    /// Board cell size, to place the label.
    let cell: CGSize
    let onDone: () -> Void

    @Environment(\.appearance) private var appearance
    @State private var risen = false
    @State private var isShown = false

    var body: some View {
        Text(points.amount, format: .number.sign(strategy: .always()))
            .font(.system(size: cell.height * 0.6, weight: .heavy, design: .rounded).monospacedDigit())
            .foregroundStyle(appearance.theme.primary)
            .shadow(color: appearance.theme.background, radius: 2)
            .fixedSize()
            .opacity(isShown ? (risen ? 0 : 1) : 0)
            .offset(y: risen ? -24 : 0)
            .position(x: points.center.x * cell.width, y: points.center.y * cell.height)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .task {
                try? await Task.sleep(for: .seconds(points.delay))
                isShown = true
                withAnimation(.easeOut(duration: FloatingPoints.duration)) { risen = true }
                try? await Task.sleep(for: .seconds(FloatingPoints.duration))
                onDone()
            }
    }
}

/// Praise next to the score ("Long shot!", "Double row!"): drops in, stays 1.2 s, fades.
/// Reduce Motion: it only appears and disappears.
struct PraiseToast: View {
    let praise: Praise
    let onDone: () -> Void

    @State private var phase = Phase.hidden
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Phase { case hidden, shown, gone }

    var body: some View {
        Toast(text: Text(praise.text))
            .scaleEffect(phase == .hidden && !reduceMotion ? 0.9 : 1)
            .offset(y: phase == .hidden && !reduceMotion ? -6 : 0)
            .opacity(phase == .shown ? 1 : 0)
            .task {
                try? await Task.sleep(for: .seconds(praise.delay))
                AccessibilityNotification.Announcement(String(localized: praise.text)).post()
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18 * EffectTiming.scale)) { phase = .shown }
                try? await Task.sleep(for: .seconds(1.2 * EffectTiming.scale))
                withAnimation(reduceMotion ? nil : .easeIn(duration: 0.2 * EffectTiming.scale)) { phase = .gone }
                try? await Task.sleep(for: .seconds(0.2 * EffectTiming.scale))
                onDone()
            }
    }
}
