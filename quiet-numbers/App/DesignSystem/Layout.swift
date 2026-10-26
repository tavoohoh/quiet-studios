import SwiftUI

/// Widths for compact (iPhone, iPad split view) and regular (iPad, Mac) layouts.
/// Compact fills the screen; regular grows the board and centers a readable column.
enum Layout {
    static func boardWidth(_ sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .regular ? 760 : 540
    }

    /// Lists, forms and leaderboards.
    static func column(_ sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .regular ? 680 : 560
    }

    /// Primary buttons on Home and the daily challenge.
    static func buttons(_ sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .regular ? 440 : 360
    }

    static func calendar(_ sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .regular ? 600 : 420
    }

    /// A board cell: 9 columns across `width` less 24 pt margins; rows 46 pt tall (52 with
    /// larger numbers), or square cells when the board is wide (iPad).
    static func boardCell(width: CGFloat, sizeClass: UserInterfaceSizeClass?, largerNumbers: Bool) -> CGSize {
        let boardWidth = min(width - 48, boardWidth(sizeClass))
        let cellWidth = (boardWidth / 9).rounded(.down)
        return CGSize(width: cellWidth, height: max(largerNumbers ? 52 : 46, cellWidth))
    }
}

extension View {
    /// Keeps List and Form rows in a centered column on wide screens, while the
    /// scroll area (and its background) still spans the whole width.
    func readableColumn() -> some View {
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
