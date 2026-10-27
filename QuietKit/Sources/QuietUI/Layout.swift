import SwiftUI

/// Widths for compact (iPhone, iPad split view) and regular (iPad, Mac) layouts.
/// Compact fills the screen; regular grows the board and centers a readable column.
public enum Layout {
    public static func boardWidth(_ sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .regular ? 760 : 540
    }

    /// Lists, forms and leaderboards.
    public static func column(_ sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .regular ? 680 : 560
    }

    /// Primary buttons on Home and the daily challenge.
    public static func buttons(_ sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .regular ? 440 : 360
    }

    public static func calendar(_ sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .regular ? 600 : 420
    }
}

extension View {
    /// Keeps List and Form rows in a centered column on wide screens, while the
    /// scroll area (and its background) still spans the whole width.
    public func readableColumn() -> some View {
        modifier(ReadableColumn())
    }
}

private struct ReadableColumn: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var width: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .contentMargins(.horizontal, max(0, (width - Layout.column(sizeClass)) / 2), for: .scrollContent)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }
}
