import QuietUI
import SwiftUI

/// The family's widths (board, column, buttons, calendar) and `readableColumn()` are in QuietUI
/// (qualified: `Layout` alone also names SwiftUI's protocol).
extension QuietUI.Layout {
    /// A board cell: 9 columns across `width` less 24 pt margins; rows 46 pt tall (52 with
    /// larger numbers), or square cells when the board is wide (iPad).
    static func boardCell(width: CGFloat, sizeClass: UserInterfaceSizeClass?, largerNumbers: Bool) -> CGSize {
        let boardWidth = min(width - 48, boardWidth(sizeClass))
        let cellWidth = (boardWidth / 9).rounded(.down)
        return CGSize(width: cellWidth, height: max(largerNumbers ? 52 : 46, cellWidth))
    }
}
