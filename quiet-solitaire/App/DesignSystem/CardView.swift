import QuietCore
import QuietSolitaireCore
import QuietUI
import SwiftUI
import UIKit

/// Colors a deck paints with. The Quiet deck and its accessibility variants follow the
/// theme; Illustrated, Classic and Pixel bring their own face (the board and back still follow).
struct DeckColors {
    let face: Color
    let border: Color
    let borderWidth: CGFloat
    let black: Color
    let red: Color
    let panel: Color
    /// Four-color deck: diamonds and clubs get their own hues.
    var diamonds: Color?
    var clubs: Color?

    init(deck: DeckStyle, theme: Theme) {
        switch deck {
        case .illustrated:
            self.init(face: .hex("#FFFFFF"), border: .hex("#D5D5D5"), black: .hex("#1B1B1B"), red: .hex("#D7322A"), panel: .hex("#F5EFE3"))
        case .classic:
            self.init(face: .hex("#FFFFFF"), border: .hex("#B5B5B5"), black: .hex("#111111"), red: .hex("#C8102E"), panel: .hex("#FBF6EA"))
        case .pixel:
            self.init(face: .hex("#F4F1E6"), border: .hex("#222034"), borderWidth: 2, black: .hex("#222034"), red: .hex("#AC3232"), panel: .hex("#E6DFCB"))
        case .quiet, .fourColor, .largeIndex:
            self.init(face: theme.surface, border: theme.isHighContrast ? theme.ink : theme.ghost,
                      borderWidth: theme.isHighContrast ? 2 : 1, black: theme.ink, red: theme.suitRed, panel: theme.surface2)
            if deck == .fourColor {
                diamonds = theme.primary
                clubs = .dynamic(light: "#3B7A3A", dark: "#8CCB84")
            }
        }
    }

    private init(face: Color, border: Color, borderWidth: CGFloat = 1, black: Color, red: Color, panel: Color) {
        self.face = face
        self.border = border
        self.borderWidth = borderWidth
        self.black = black
        self.red = red
        self.panel = panel
    }

    func color(for suit: Suit) -> Color {
        switch suit {
        case .spades: black
        case .hearts: red
        case .diamonds: diamonds ?? red
        case .clubs: clubs ?? black
        }
    }
}

extension Color {
    static func hex(_ value: String) -> Color {
        let (r, g, b) = Contrast.components(value)
        return Color(red: r, green: g, blue: b)
    }

    static func dynamic(light: String, dark: String) -> Color {
        let l = Contrast.components(light), d = Contrast.components(dark)
        return Color(uiColor: UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? d : l
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }
}

extension Card {
    var rankLabel: String { ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"][rank - 1] }
    var isCourt: Bool { rank > 10 }
    var suitAsset: String { "suit-" + ["s", "h", "d", "c"][suit.rawValue] }
}

/// Card height for a width: 1.4 everywhere.
func cardHeightFor(_ width: CGFloat) -> CGFloat { (width * 1.4).rounded() }

// MARK: Face

/// A face-up card, laid out like the canvas: index top left, then one body box below it
/// (8 % margins) that holds the pip, the ace's larger pip or the court's panel.
struct CardFace: View {
    let card: Card
    let deck: DeckStyle
    let width: CGFloat

    @Environment(\.quietTheme) private var theme

    var body: some View {
        let colors = DeckColors(deck: deck, theme: theme)
        let height = cardHeightFor(width)
        let shape = CardShape(deck: deck, width: width)
        ZStack(alignment: .topLeading) {
            shape.fill(colors.face)
            if deck == .classic {
                ClassicFace(card: card, width: width, height: height, colors: colors)
            } else {
                ModernFace(card: card, deck: deck, width: width, height: height, colors: colors)
            }
        }
        .frame(width: width, height: height)
        .clipShape(shape)
        .overlay { shape.strokeBorder(colors.border, lineWidth: colors.borderWidth) }
    }
}

/// Rounded rectangle; the Pixel deck gets stepped corners instead.
struct CardShape: InsettableShape {
    let deck: DeckStyle
    let width: CGFloat
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: inset, dy: inset)
        if deck == .pixel {
            let u = max(2, (width / 30).rounded())
            var path = Path()
            path.addLines([
                CGPoint(x: rect.minX + u, y: rect.minY), CGPoint(x: rect.maxX - u, y: rect.minY),
                CGPoint(x: rect.maxX - u, y: rect.minY + u), CGPoint(x: rect.maxX, y: rect.minY + u),
                CGPoint(x: rect.maxX, y: rect.maxY - u), CGPoint(x: rect.maxX - u, y: rect.maxY - u),
                CGPoint(x: rect.maxX - u, y: rect.maxY), CGPoint(x: rect.minX + u, y: rect.maxY),
                CGPoint(x: rect.minX + u, y: rect.maxY - u), CGPoint(x: rect.minX, y: rect.maxY - u),
                CGPoint(x: rect.minX, y: rect.minY + u), CGPoint(x: rect.minX + u, y: rect.minY + u),
            ])
            path.closeSubpath()
            return path
        }
        let radius = max(4, width * (deck == .classic ? 0.07 : 0.1))
        return RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect)
    }

    func inset(by amount: CGFloat) -> CardShape {
        var shape = self
        shape.inset += amount
        return shape
    }
}

private struct ModernFace: View {
    let card: Card
    let deck: DeckStyle
    let width: CGFloat
    let height: CGFloat
    let colors: DeckColors

    var body: some View {
        let color = colors.color(for: card.suit)
        let large = deck == .largeIndex
        let pixel = deck == .pixel
        let margin = (width * 0.08).rounded()
        let bodyTop = (height * (large ? 0.4 : 0.34)).rounded()
        let bodySize = CGSize(width: width - margin * 2, height: height - bodyTop - margin)
        let smallSuit = (width * (large ? 0.3 : 0.24)).rounded()
        ZStack(alignment: .topLeading) {
            HStack(spacing: max(1, (width * 0.025).rounded())) {
                if pixel {
                    PixelGlyph(rows: PixelArt.rank(card.rankLabel), unit: max(1, (width * 0.05).rounded()), color: color)
                } else {
                    Text(verbatim: card.rankLabel)
                        .font(.system(size: (width * (large ? 0.42 : deck == .illustrated ? 0.36 : 0.34)).rounded(),
                                      weight: deck == .illustrated ? .heavy : .bold, design: .rounded))
                        .tracking(card.rank == 10 ? -width * 0.03 : 0)
                        .foregroundStyle(color)
                        .fixedSize()
                }
                SuitMark(suit: card.suit, pixel: pixel, color: color)
                    .frame(width: smallSuit, height: smallSuit)
            }
            .frame(height: (width * (large ? 0.42 : 0.34)).rounded())
            .offset(x: margin, y: (width * (pixel ? 0.09 : 0.06)).rounded())

            Group {
                if card.isCourt {
                    if deck == .illustrated || pixel {
                        Portrait(card: card, look: pixel ? .pixel : .illustrated, color: color)
                            .frame(width: bodySize.width, height: bodySize.height)
                            .background(colors.panel)
                            .clipShape(RoundedRectangle(cornerRadius: pixel ? 0 : max(3, width * 0.06), style: .continuous))
                    } else {
                        Image("emblem-" + card.rankLabel)
                            .resizable()
                            .renderingMode(.template)
                            .foregroundStyle(color)
                            .frame(width: min(bodySize.width, bodySize.height) * 0.72, height: min(bodySize.width, bodySize.height) * 0.72)
                            .frame(width: bodySize.width, height: bodySize.height)
                            .background(colors.panel, in: RoundedRectangle(cornerRadius: max(3, width * 0.06), style: .continuous))
                    }
                } else {
                    let pip = (width * (card.rank == 1 ? 0.6 : large ? 0.4 : 0.5)).rounded()
                    SuitMark(suit: card.suit, pixel: pixel, color: color)
                        .frame(width: pip, height: pip)
                        .frame(width: bodySize.width, height: bodySize.height)
                }
            }
            .offset(x: margin, y: bodyTop)
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }
}

/// The table deck: indexes in two corners, pips laid out by rank, framed double-headed courts.
private struct ClassicFace: View {
    let card: Card
    let width: CGFloat
    let height: CGFloat
    let colors: DeckColors

    private static let left = 0.39, center = 0.5, right = 0.61
    private static let pips: [Int: [(Double, Double)]] = [
        2: [(center, 0.2), (center, 0.8)],
        3: [(center, 0.2), (center, 0.5), (center, 0.8)],
        4: [(left, 0.2), (right, 0.2), (left, 0.8), (right, 0.8)],
        5: [(left, 0.2), (right, 0.2), (center, 0.5), (left, 0.8), (right, 0.8)],
        6: [(left, 0.2), (right, 0.2), (left, 0.5), (right, 0.5), (left, 0.8), (right, 0.8)],
        7: [(left, 0.2), (right, 0.2), (center, 0.35), (left, 0.5), (right, 0.5), (left, 0.8), (right, 0.8)],
        8: [(left, 0.2), (right, 0.2), (center, 0.35), (left, 0.5), (right, 0.5), (center, 0.65), (left, 0.8), (right, 0.8)],
        9: [(left, 0.2), (right, 0.2), (left, 0.4), (right, 0.4), (center, 0.5), (left, 0.6), (right, 0.6), (left, 0.8), (right, 0.8)],
        10: [(left, 0.2), (right, 0.2), (center, 0.3), (left, 0.4), (right, 0.4), (left, 0.6), (right, 0.6), (center, 0.7), (left, 0.8), (right, 0.8)],
    ]

    var body: some View {
        let color = colors.color(for: card.suit)
        ZStack(alignment: .topLeading) {
            index(color)
                .offset(x: (width * 0.03).rounded(), y: (width * 0.05).rounded())
            index(color)
                .rotationEffect(.degrees(180))
                .offset(x: width - (width * 0.25).rounded(), y: height - (width * 0.05).rounded() - indexHeight)
            if card.isCourt {
                let frameX = (width * 0.25).rounded(), frameY = (height * 0.09).rounded()
                let size = CGSize(width: width - frameX * 2, height: height - frameY * 2)
                VStack(spacing: 0) {
                    Portrait(card: card, look: .classic, color: color)
                    Rectangle().fill(color).frame(height: 1)
                    Portrait(card: card, look: .classic, color: color).rotationEffect(.degrees(180))
                }
                .frame(width: size.width, height: size.height)
                .background(colors.panel)
                .overlay { Rectangle().strokeBorder(color, lineWidth: 1) }
                .offset(x: frameX, y: frameY)
            } else if card.rank == 1 {
                let pip = (width * 0.42).rounded()
                SuitMark(suit: card.suit, pixel: false, color: color)
                    .frame(width: pip, height: pip)
                    .offset(x: (width - pip) / 2, y: (height - pip) / 2)
            } else {
                let pip = (width * 0.16).rounded()
                ForEach(Array((Self.pips[card.rank] ?? []).enumerated()), id: \.offset) { _, spot in
                    SuitMark(suit: card.suit, pixel: false, color: color)
                        .frame(width: pip, height: pip)
                        .rotationEffect(.degrees(spot.1 > 0.5 ? 180 : 0))
                        .offset(x: (spot.0 * width - pip / 2).rounded(), y: (spot.1 * height - pip / 2).rounded())
                }
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
    }

    private var indexHeight: CGFloat { (width * 0.23).rounded() + 1 + (width * 0.15).rounded() }

    private func index(_ color: Color) -> some View {
        VStack(spacing: 1) {
            Text(verbatim: card.rankLabel)
                .font(.system(size: (width * 0.23).rounded(), weight: .bold, design: .serif))
                .tracking(card.rank == 10 ? -width * 0.02 : 0)
                .foregroundStyle(color)
                .fixedSize()
            SuitMark(suit: card.suit, pixel: false, color: color)
                .frame(width: (width * 0.15).rounded(), height: (width * 0.15).rounded())
        }
        .frame(width: (width * 0.22).rounded())
    }
}

/// A suit symbol: vector, or drawn pixel by pixel.
struct SuitMark: View {
    let suit: Suit
    let pixel: Bool
    let color: Color

    var body: some View {
        if pixel {
            GeometryReader { geometry in
                PixelGlyph(rows: PixelArt.suits[suit.rawValue], unit: geometry.size.width / 9, color: color)
            }
        } else {
            Image(["suit-s", "suit-h", "suit-d", "suit-c"][suit.rawValue])
                .resizable()
                .renderingMode(.template)
                .foregroundStyle(color)
        }
    }
}

/// Court figure: Illustrated and Classic from the asset catalog, Pixel drawn here.
struct Portrait: View {
    enum Look { case illustrated, classic, pixel }

    let card: Card
    let look: Look
    let color: Color

    var body: some View {
        switch look {
        case .pixel:
            GeometryReader { geometry in
                let unit = min(geometry.size.width / 11, geometry.size.height / 14)
                PixelPortrait(rank: card.rankLabel, unit: unit, robe: color)
                    .frame(width: unit * 11, height: unit * 14)
                    .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
            }
        case .illustrated, .classic:
            Image("portrait-\(look == .classic ? "classic" : "illus")-\(card.rankLabel)-\(card.isRed ? "red" : "black")")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
    }
}

// MARK: Back and slots

struct CardBackView: View {
    let back: CardBack
    let width: CGFloat

    @Environment(\.quietTheme) private var theme

    var body: some View {
        let height = cardHeightFor(width)
        let style = BackStyle(back: back, palette: theme.palette)
        let shape = RoundedRectangle(cornerRadius: max(4, width * 0.1), style: .continuous)
        let mark = (width * 0.34).rounded()
        let line = max(1, width * 0.016)
        ZStack {
            shape.fill(style.fill)
            Canvas { context, size in style.drawPattern(in: &context, size: size) }
                .clipShape(shape)
            RoundedRectangle(cornerRadius: max(3, width * 0.06), style: .continuous)
                .strokeBorder(style.line, lineWidth: line)
                .padding((width * 0.08).rounded())
            Circle()
                .strokeBorder(style.mark, lineWidth: line)
                .frame(width: mark, height: mark)
                .overlay {
                    HStack(spacing: max(2, mark * 0.14)) {
                        Capsule().fill(style.mark).frame(width: max(1.5, width * 0.035), height: mark * 0.36)
                        Capsule().fill(style.mark).frame(width: max(1.5, width * 0.035), height: mark * 0.36)
                    }
                }
        }
        .frame(width: width, height: height)
        .overlay { if theme.isHighContrast { shape.strokeBorder(theme.ink, lineWidth: 2) } }
    }
}

/// Colors and pattern of a card back.
struct BackStyle {
    let back: CardBack
    let fill: Color
    let line: Color
    let mark: Color
    private let pattern: Color

    init(back: CardBack, palette: Palette) {
        self.back = back
        switch back {
        case .theme:
            fill = switch palette {
            case .tealCoral: .dynamic(light: "#0E6B78", dark: "#1D5961")
            case .sageSand: .hex("#387454")
            case .indigoPeach: .hex("#3A3878")
            case .sageCoral: .hex("#4D7157")
            case .highContrast: .hex("#003F91")
            }
            (line, mark, pattern) = (.white.opacity(0.32), .white.opacity(0.62), .white.opacity(0.07))
        case .coral:
            fill = .hex("#B9472F")
            (line, mark, pattern) = (.white.opacity(0.34), .white.opacity(0.7), .white.opacity(0.09))
        case .night:
            fill = .hex("#1B2140")
            (line, mark, pattern) = (.hex("#FFD49A").opacity(0.35), .hex("#FFD49A").opacity(0.85), .white.opacity(0.26))
        case .linen:
            fill = .hex("#E4D8C0")
            let brown = Color(red: 90 / 255, green: 70 / 255, blue: 40 / 255)
            (line, mark, pattern) = (brown.opacity(0.35), brown.opacity(0.62), brown.opacity(0.10))
        case .gold:
            fill = .hex("#9A7628")
            let cream = Color(red: 1, green: 236 / 255, blue: 190 / 255)
            (line, mark, pattern) = (cream.opacity(0.55), cream.opacity(0.9), cream.opacity(0.13))
        }
    }

    func drawPattern(in context: inout GraphicsContext, size: CGSize) {
        var path = Path()
        switch back {
        case .theme, .gold:
            stride(from: -size.height, through: size.width, by: 6).forEach { x in
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
            }
        case .coral:
            stride(from: 0, through: size.height, by: 5).forEach { y in
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
        case .linen:
            stride(from: -size.height, through: size.width, by: 5).forEach { x in
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x + size.height, y: size.height))
            }
        case .night:
            for x in stride(from: 4.5, to: size.width, by: 9) {
                for y in stride(from: 4.5, to: size.height, by: 9) {
                    path.addEllipse(in: CGRect(x: x - 0.9, y: y - 0.9, width: 1.8, height: 1.8))
                }
            }
            context.fill(path, with: .color(pattern))
            return
        }
        context.stroke(path, with: .color(pattern), lineWidth: 1)
    }
}

/// An empty place on the table.
struct SlotView: View {
    enum Glyph: Equatable {
        case none
        case suit(Suit)
        case recycle
    }

    let glyph: Glyph
    let width: CGFloat
    var isTarget = false

    @Environment(\.quietTheme) private var theme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: max(4, width * 0.1), style: .continuous)
        shape
            .fill(isTarget ? theme.primary.opacity(0.22) : theme.surface2.opacity(theme.isHighContrast ? 1 : 0.75))
            .overlay {
                if theme.isHighContrast { shape.strokeBorder(theme.ink, style: StrokeStyle(lineWidth: 2, dash: [4, 3])) }
            }
            .overlay {
                switch glyph {
                case .none: EmptyView()
                case .suit(let suit):
                    SuitMark(suit: suit, pixel: false, color: theme.ghost)
                        .frame(width: width * 0.42, height: width * 0.42)
                case .recycle:
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: width * 0.36, weight: .semibold))
                        .foregroundStyle(theme.ghost)
                }
            }
            .frame(width: width, height: cardHeightFor(width))
    }
}
