#if canImport(UIKit)
import QuietCore
import SwiftUI

/// Classic fireworks for a win: rockets rise from the bottom, burst into sparks that fall
/// with gravity and fade. Drawn from the time since start (no per-frame state), with our
/// seeded random so a given `seed` always looks the same. Doesn't take touches.
/// With Reduce Motion it draws nothing; callers show their own static message.
public struct Fireworks: View {
    let colors: [Color]
    let rockets: Int
    let seed: UInt64

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date.now

    public init(colors: [Color], rockets: Int = 12, seed: UInt64 = 7) {
        self.colors = colors
        self.rockets = rockets
        self.seed = seed
    }

    /// When the last spark is gone.
    public static func duration(rockets: Int = 12) -> Double {
        Double(rockets - 1) * stagger + rise + sparkLife
    }

    private static let stagger = 0.26
    private static let rise = 0.7
    private static let sparkLife = 1.4
    private static let sparks = 40
    private static let gravity: Double = 220

    private struct Rocket {
        let launch: Double
        let x: Double
        let burst: CGPoint
        let speed: Double
        let color: Int
        let twinkle: Bool
    }

    public var body: some View {
        if !reduceMotion {
            GeometryReader { geometry in
                let rockets = makeRockets(size: geometry.size)
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        let t = timeline.date.timeIntervalSince(start)
                        for rocket in rockets { draw(rocket, at: t - rocket.launch, size: size, in: &context) }
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func makeRockets(size: CGSize) -> [Rocket] {
        var random = SeededRandom(seed: seed)
        func unit() -> Double { Double(random.nextInt(in: 0...10_000)) / 10_000 }
        return (0..<rockets).map { i in
            let x = size.width * (0.15 + 0.7 * unit())
            return Rocket(
                launch: Double(i) * Self.stagger,
                x: x,
                burst: CGPoint(x: x + (unit() - 0.5) * size.width * 0.2, y: size.height * (0.15 + 0.3 * unit())),
                speed: 140 + 90 * unit(),
                color: random.nextInt(in: 0...(max(colors.count, 1) - 1)),
                twinkle: unit() > 0.5
            )
        }
    }

    private func draw(_ rocket: Rocket, at t: Double, size: CGSize, in context: inout GraphicsContext) {
        guard t >= 0, !colors.isEmpty else { return }
        let color = colors[rocket.color]
        if t < Self.rise {
            // The rising trail: ease-out from the bottom to the burst point.
            let p = 1 - pow(1 - t / Self.rise, 2)
            let y = size.height + (rocket.burst.y - size.height) * p
            let x = rocket.x + (rocket.burst.x - rocket.x) * p
            var trail = Path()
            trail.move(to: CGPoint(x: x, y: y))
            trail.addLine(to: CGPoint(x: x - (rocket.burst.x - rocket.x) * 0.06, y: y + 18))
            context.stroke(trail, with: .color(color.opacity(0.8)), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            return
        }
        let s = t - Self.rise
        guard s < Self.sparkLife else { return }
        let fade = 1 - s / Self.sparkLife
        // A soft flash at the burst.
        if s < 0.15 {
            let r = 44 * (s / 0.15)
            context.fill(Path(ellipseIn: CGRect(x: rocket.burst.x - r, y: rocket.burst.y - r, width: r * 2, height: r * 2)),
                         with: .color(color.opacity(0.35 * (1 - s / 0.15))))
        }
        for j in 0..<Self.sparks {
            let angle = Double(j) / Double(Self.sparks) * 2 * .pi + Double(rocket.color) * 0.3
            let v = rocket.speed * (j.isMultiple(of: 2) ? 1 : 0.72)
            let drag = (1 - exp(-1.8 * s)) / 1.8
            let x = rocket.burst.x + cos(angle) * v * drag
            let y = rocket.burst.y + sin(angle) * v * drag + 0.5 * Self.gravity * s * s
            let tailX = rocket.burst.x + cos(angle) * v * drag * 0.78
            let tailY = rocket.burst.y + sin(angle) * v * drag * 0.78 + 0.5 * Self.gravity * s * s * 0.9
            var spark = Path()
            spark.move(to: CGPoint(x: tailX, y: tailY))
            spark.addLine(to: CGPoint(x: x, y: y))
            let blink = rocket.twinkle && s > 0.6 ? (sin(s * 40 + Double(j)) > 0 ? 1.0 : 0.3) : 1.0
            context.stroke(spark, with: .color(color.opacity(fade * blink)), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            // A bright head on each spark.
            context.fill(Path(ellipseIn: CGRect(x: x - 1.8, y: y - 1.8, width: 3.6, height: 3.6)), with: .color(color.opacity(fade * blink)))
        }
    }
}
#endif
