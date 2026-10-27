import SwiftUI

extension Font {
    /// The game's score, 44 pt at the default text size.
    public static func score(size: CGFloat = 44, design: Font.Design = .rounded) -> Font {
        .system(size: size, weight: .heavy, design: design).monospacedDigit()
    }

    public static let score = score()
    public static let counter = Font.system(.subheadline, weight: .medium).monospacedDigit()
    /// Values in stat tiles ("2,480", "8").
    public static let stat = Font.system(.title2, design: .rounded, weight: .heavy).monospacedDigit()
}

extension Animation {
    /// The family's default: quick with a little overshoot.
    public static let quiet = Animation.snappy(duration: 0.2 * EffectTiming.scale, extraBounce: 0.12)
}

public enum EffectTiming {
    /// Multiplies effect durations. DEBUG `-slowEffects` slows them down to inspect them.
    public static let scale: Double = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-slowEffects") { return 6 }
        #endif
        return 1
    }()
}
