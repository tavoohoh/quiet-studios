import SwiftUI

/// Where flying points land: just right of the score.
struct ScoreAnchorKey: SwiftUI.PreferenceKey {
    static let defaultValue: Anchor<CGPoint>? = nil

    static func reduce(value: inout Anchor<CGPoint>?, nextValue: () -> Anchor<CGPoint>?) {
        value = value ?? nextValue()
    }
}

/// Praise and match points, over the whole game screen. Both start in the middle:
/// points fly to the score, praise rises in its bubble to the top center.
struct GameFeedbackOverlay: View {
    let model: GameModel
    let scoreAnchor: Anchor<CGPoint>?

    var body: some View {
        GeometryReader { proxy in
            let middle = CGPoint(x: proxy.size.width / 2, y: proxy.size.height * 0.42)
            let score = scoreAnchor.map { proxy[$0] } ?? CGPoint(x: middle.x, y: 0)
            ZStack {
                if let flight = model.scoreFlight {
                    FlyingPoints(
                        flight: flight,
                        from: middle,
                        to: CGPoint(x: score.x + 24, y: score.y),
                        onLanded: { model.land(flight) }
                    )
                    .id(flight.id)
                }
                if let praise = model.praise {
                    PraiseBubble(
                        praise: praise,
                        from: CGPoint(x: middle.x, y: middle.y + 64),
                        to: CGPoint(x: proxy.size.width / 2, y: score.y),
                        onDone: { model.dismissPraise(praise) }
                    )
                    .id(praise.id)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// "+4": pops in at `from`, flies to `to` while shrinking, fades on arrival.
private struct FlyingPoints: View {
    let flight: ScoreFlight
    let from: CGPoint
    let to: CGPoint
    let onLanded: () -> Void

    @State private var phase = Phase.hidden

    private enum Phase { case hidden, shown, flown }

    var body: some View {
        Text(flight.amount, format: .number.sign(strategy: .always()))
            .font(.system(.largeTitle, design: .rounded, weight: .bold).monospacedDigit())
            .foregroundStyle(.tint)
            .scaleEffect(phase == .hidden ? 0.4 : phase == .shown ? 1 : 0.5)
            .opacity(phase == .hidden ? 0 : 1)
            .position(phase == .flown ? to : from)
            .accessibilityHidden(true)
            .task {
                try? await Task.sleep(for: .seconds(flight.delay))
                withAnimation(.snappy(duration: 0.18 * EffectTiming.scale, extraBounce: 0.25)) { phase = .shown }
                try? await Task.sleep(for: .seconds(0.3 * EffectTiming.scale))
                let travel = 0.32 * EffectTiming.scale
                withAnimation(.timingCurve(0.5, 0, 0.8, 0.6, duration: travel)) { phase = .flown }
                try? await Task.sleep(for: .seconds(travel))
                withAnimation(.quiet) { onLanded() }
            }
    }
}

/// A bubble in the middle of the screen that rises to the top center and fades there.
private struct PraiseBubble: View {
    let praise: Praise
    let from: CGPoint
    let to: CGPoint
    let onDone: () -> Void

    @State private var phase = Phase.hidden
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum Phase { case hidden, shown, risen, gone }

    var body: some View {
        Text(praise.text)
            .font(.system(.title3, design: .rounded, weight: .bold))
            .foregroundStyle(Color.highlight)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.regularMaterial, in: Capsule())
            .overlay { Capsule().strokeBorder(Color.highlight.opacity(0.35), lineWidth: 1) }
            .scaleEffect(scale)
            .opacity(phase == .hidden || phase == .gone ? 0 : 1)
            .position(reduceMotion || phase == .risen || phase == .gone ? to : from)
            .task {
                try? await Task.sleep(for: .seconds(praise.delay))
                AccessibilityNotification.Announcement(String(localized: praise.text)).post()
                withAnimation(.snappy(duration: 0.2 * EffectTiming.scale, extraBounce: 0.3)) { phase = .shown }
                try? await Task.sleep(for: .seconds(0.7 * EffectTiming.scale))
                withAnimation(.smooth(duration: 0.35 * EffectTiming.scale)) { phase = .risen }
                try? await Task.sleep(for: .seconds(0.9 * EffectTiming.scale))
                withAnimation(.easeOut(duration: 0.25 * EffectTiming.scale)) { phase = .gone }
                try? await Task.sleep(for: .seconds(0.25 * EffectTiming.scale))
                onDone()
            }
    }

    private var scale: CGFloat {
        switch phase {
        case .hidden: reduceMotion ? 1 : 0.5
        case .shown: 1
        case .risen, .gone: 0.85
        }
    }
}
