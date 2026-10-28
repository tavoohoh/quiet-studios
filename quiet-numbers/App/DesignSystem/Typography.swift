import SwiftUI

/// The family's type (`score`, `counter`, `stat`, `Animation.quiet`, `EffectTiming`) is in QuietUI.
extension Font {
    /// Numbers on the board: SF Pro Rounded, fixed-width digits so the grid lines up.
    static func boardNumber(size: CGFloat, design: Font.Design = .rounded) -> Font {
        .system(size: size, weight: .regular, design: design).monospacedDigit()
    }
}
