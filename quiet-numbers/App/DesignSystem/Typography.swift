import SwiftUI

extension Font {
    /// Numbers on the board: SF Pro Rounded, fixed-width digits so the grid lines up.
    static func boardNumber(size: CGFloat, design: Font.Design = .rounded) -> Font {
        .system(size: size, weight: .medium, design: design).monospacedDigit()
    }

    static func score(design: Font.Design = .rounded) -> Font {
        .system(.largeTitle, design: design, weight: .semibold).monospacedDigit()
    }

    static let score = score()
    static let counter = Font.system(.subheadline, design: .rounded, weight: .medium).monospacedDigit()
}

extension Animation {
    /// The app's default: quick with a little overshoot.
    static let quiet = Animation.snappy(duration: 0.2 * EffectTiming.scale, extraBounce: 0.12)
}

enum EffectTiming {
    /// Multiplies effect durations. DEBUG `-slowEffects` slows them down to inspect them.
    static let scale: Double = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-slowEffects") { return 6 }
        #endif
        return 1
    }()
}
