import QuietSolitaireCore
import SwiftUI

/// Where everything sits on the table for a given size.
/// iPhone: 7 columns of (width − 18 − 6 × gap) / 7, cards 1.4 tall; face-down cards show
/// 19 % of the width, face-up 46 % (just the index). Long columns squeeze their face-up
/// step down to 16 pt so they never run off the bottom.
struct BoardLayout {
    let cardWidth: CGFloat
    let cardHeight: CGFloat
    let gap: CGFloat
    let origin: CGFloat
    let leftHanded: Bool
    let tableauTop: CGFloat
    let height: CGFloat

    init(size: CGSize, maxWidth: CGFloat, leftHanded: Bool) {
        let boardWidth = min(size.width - 18, maxWidth)
        gap = boardWidth > 600 ? 12 : 6
        cardWidth = ((boardWidth - gap * 6) / 7).rounded(.down)
        cardHeight = cardHeightFor(cardWidth)
        origin = ((size.width - (cardWidth * 7 + gap * 6)) / 2).rounded()
        self.leftHanded = leftHanded
        tableauTop = cardHeight + max(14, cardWidth * 0.36)
        height = size.height
    }

    func x(column: Int) -> CGFloat { origin + CGFloat(column) * (cardWidth + gap) }

    /// Top row: foundations on the left and the stock on the right, or mirrored.
    func topColumn(_ location: TopSlot) -> Int {
        let right: Int = switch location {
        case .foundation(let suit): suit.rawValue
        case .waste: 5
        case .stock: 6
        }
        return leftHanded ? 6 - right : right
    }

    enum TopSlot: Hashable {
        case foundation(Suit)
        case waste
        case stock
    }

    func frame(_ slot: TopSlot) -> CGRect {
        CGRect(x: x(column: topColumn(slot)), y: 0, width: cardWidth, height: cardHeight)
    }

    /// Steps between cards in a column, squeezed if the column would overflow.
    func steps(for column: [TableauCard]) -> (down: CGFloat, up: CGFloat) {
        let down = (cardWidth * 0.19).rounded()
        var up = (cardWidth * 0.46).rounded()
        let faceDown = column.filter { !$0.isFaceUp }.count
        let faceUp = max(0, column.count - faceDown - 1)
        let available = height - tableauTop - cardHeight - 8
        if faceUp > 0, CGFloat(faceDown) * down + CGFloat(faceUp) * up > available {
            up = max(16, ((available - CGFloat(faceDown) * down) / CGFloat(faceUp)).rounded(.down))
        }
        return (down, up)
    }

    /// Top-left corner of each card in a column.
    func positions(column index: Int, cards: [TableauCard]) -> [CGPoint] {
        let (down, up) = steps(for: cards)
        var y = tableauTop
        return cards.map { card in
            defer { y += card.isFaceUp ? up : down }
            return CGPoint(x: x(column: index), y: y)
        }
    }

    /// The drop target under a point, if any.
    func location(at point: CGPoint, state: GameState, carrying count: Int) -> Location? {
        if point.y < tableauTop - 4 {
            for suit in Suit.allCases where count == 1 && frame(.foundation(suit)).insetBy(dx: -gap / 2, dy: -12).contains(point) {
                return .foundation(suit)
            }
            return nil
        }
        for column in 0..<7 {
            let x = x(column: column)
            if point.x >= x - gap / 2, point.x <= x + cardWidth + gap / 2 { return .tableau(column) }
        }
        return nil
    }
}
