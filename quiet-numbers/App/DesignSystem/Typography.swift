import SwiftUI

extension Font {
    /// Numbers on the board: SF Pro Rounded, fixed-width digits so the grid lines up.
    static func boardNumber(size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .rounded).monospacedDigit()
    }

    static let score = Font.system(.largeTitle, design: .rounded, weight: .semibold).monospacedDigit()
    static let counter = Font.system(.subheadline, design: .rounded, weight: .medium).monospacedDigit()
}

extension Animation {
    static let quiet = Animation.smooth(duration: 0.3)
}
