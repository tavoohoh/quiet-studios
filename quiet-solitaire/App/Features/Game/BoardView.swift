import QuietSolitaireCore
import QuietUI
import SwiftUI

/// The table: slots, then all 52 cards, each placed by `BoardLayout` so every move animates
/// as the card sliding to its new place. Tap a card to send it to its best place, drag to
/// choose; tap the stock to draw.
struct BoardView: View {
    let model: GameModel
    let layout: BoardLayout

    @Environment(\.quietTheme) private var theme
    @Environment(\.appearance) private var appearance
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(PreferenceKey.tapToMove) private var tapToMove = true
    /// Cards being dragged, and how far.
    @State private var drag: (ids: [Int], offset: CGSize)?
    @State private var dropTarget: Location?
    /// Kept while a won game celebrates.
    @State private var celebrating = false

    /// Drags are measured on the table, not on the card (which moves with the finger).
    private static let space = "board"

    var body: some View {
        let state = model.state
        let placements = placements(for: state)
        ZStack(alignment: .topLeading) {
            slots(state)
            ForEach(Card.deck, id: \.id) { card in
                if let placement = placements[card.id] {
                    cardView(card, placement: placement)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .coordinateSpace(.named(Self.space))
        .overlay(alignment: .topLeading) { foundationBurst }
        .onChange(of: state.isWon) { _, won in
            guard won, appearance.victory == .cascade, !reduceMotion else { return }
            celebrating = true
        }
    }

    // MARK: Slots

    private func slots(_ state: GameState) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Suit.allCases, id: \.self) { suit in
                SlotView(glyph: .suit(suit), width: layout.cardWidth, isTarget: dropTarget == .foundation(suit))
                    .offset(origin(layout.frame(.foundation(suit))))
                    .accessibilityHidden(true)
            }
            SlotView(glyph: .none, width: layout.cardWidth)
                .offset(origin(layout.frame(.waste)))
                .accessibilityHidden(true)
            Button(action: model.drawFromStock) {
                SlotView(glyph: state.waste.isEmpty ? .none : .recycle, width: layout.cardWidth)
            }
            .buttonStyle(.plain)
            .offset(origin(layout.frame(.stock)))
            .accessibilityLabel(Text("Stock"))
            .accessibilityHint(Text(state.waste.isEmpty ? "Empty" : "Turn the waste over"))
            .accessibilityIdentifier("stock")
            ForEach(0..<7, id: \.self) { column in
                SlotView(glyph: .none, width: layout.cardWidth, isTarget: dropTarget == .tableau(column))
                    .opacity(state.tableau[column].isEmpty || dropTarget == .tableau(column) ? 1 : 0)
                    .offset(x: layout.x(column: column), y: layout.tableauTop)
                    .accessibilityHidden(true)
            }
        }
    }

    private func origin(_ rect: CGRect) -> CGSize { CGSize(width: rect.minX, height: rect.minY) }

    // MARK: Cards

    private struct Placement {
        var point: CGPoint
        var isFaceUp: Bool
        var z: Double
        var area: Area
        /// Order in its pile, for VoiceOver and the cascade.
        var index: Int
    }

    private enum Area { case stock, waste, foundation(Suit), tableau(Int) }

    private func placements(for state: GameState) -> [Int: Placement] {
        var result: [Int: Placement] = [:]
        let stock = layout.frame(.stock).origin
        for (i, card) in state.stock.enumerated() {
            result[card.id] = Placement(point: stock, isFaceUp: false, z: Double(i), area: .stock, index: i)
        }
        let waste = layout.frame(.waste).origin
        for (i, card) in state.waste.enumerated() {
            result[card.id] = Placement(point: waste, isFaceUp: true, z: 100 + Double(i), area: .waste, index: i)
        }
        for suit in Suit.allCases {
            let point = layout.frame(.foundation(suit)).origin
            for (i, card) in state.foundation(suit).enumerated() {
                result[card.id] = Placement(point: point, isFaceUp: true, z: 200 + Double(i), area: .foundation(suit), index: i)
            }
        }
        for column in 0..<7 {
            let cards = state.tableau[column]
            for (i, point) in layout.positions(column: column, cards: cards).enumerated() {
                result[cards[i].card.id] = Placement(point: point, isFaceUp: cards[i].isFaceUp, z: 300 + Double(i), area: .tableau(column), index: i)
            }
        }
        return result
    }

    @ViewBuilder
    private func cardView(_ card: Card, placement: Placement) -> some View {
        let dragged = drag?.ids.contains(card.id) == true
        let isHint = hintIDs.contains(card.id)
        let z = dragged ? 2_000 + placement.z : model.inFlight.contains(card.id) ? 1_000 + placement.z : placement.z
        FlippableCard(card: card, isFaceUp: placement.isFaceUp, deck: appearance.deck, back: appearance.back, width: layout.cardWidth)
            .overlay {
                if isHint {
                    HintRing(width: layout.cardWidth)
                }
            }
            .shadow(color: .black.opacity(dragged ? 0.22 : 0), radius: dragged ? 10 : 0, y: dragged ? 6 : 0)
            .modifier(Shake(amount: model.rejected.contains(card.id) ? 1 : 0))
            .animation(.linear(duration: 0.24), value: model.rejected.contains(card.id))
            .offset(x: placement.point.x + (dragged ? drag!.offset.width : 0) + celebrationOffset(placement).width,
                    y: placement.point.y + (dragged ? drag!.offset.height : 0) + celebrationOffset(placement).height)
            .animation(celebrating ? .easeIn(duration: 0.9).delay(celebrationDelay(placement)) : nil, value: celebrating)
            .zIndex(z)
            .onTapGesture { tapped(card, placement: placement) }
            .gesture(dragGesture(for: card, placement: placement))
            .allowsHitTesting(isInteractive(placement))
            .accessibilityElement()
            .accessibilityLabel(accessibilityLabel(card, placement: placement))
            .accessibilityAddTraits(isInteractive(placement) ? .isButton : [])
            .accessibilityAction { tapped(card, placement: placement) }
            .accessibilityHidden(!isVisible(placement))
    }

    private func isInteractive(_ placement: Placement) -> Bool {
        switch placement.area {
        case .stock: return true
        case .waste: return placement.index == model.state.waste.count - 1
        case .foundation(let suit): return placement.index == model.state.foundation(suit).count - 1
        case .tableau: return placement.isFaceUp
        }
    }

    /// Hidden from VoiceOver: cards fully covered in a pile.
    private func isVisible(_ placement: Placement) -> Bool {
        switch placement.area {
        case .stock: placement.index == model.state.stock.count - 1
        case .waste, .foundation: isInteractive(placement)
        case .tableau: true
        }
    }

    private func tapped(_ card: Card, placement: Placement) {
        if case .stock = placement.area { return model.drawFromStock() }
        guard tapToMove else { return }
        model.tap(card.id)
    }

    private func dragGesture(for card: Card, placement: Placement) -> some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named(Self.space))
            .onChanged { value in
                guard placement.isFaceUp, model.locate(card.id) != nil else { return }
                if drag == nil {
                    FeedbackService.shared.play(.pickUp)
                    drag = (model.carried(from: card.id), .zero)
                }
                drag?.offset = value.translation
                dropTarget = target(for: drag?.ids ?? [], from: placement, translation: value.translation, finger: value.location)
            }
            .onEnded { value in
                guard let current = drag else { return }
                let target = target(for: current.ids, from: placement, translation: value.translation, finger: value.location)
                dropTarget = nil
                // One transaction: the cards glide from where the finger left them, either to
                // their new place or back home.
                withAnimation(.spring(duration: 0.28, bounce: 0.12)) {
                    drag = nil
                    if let target { model.drop(card.id, on: target) }
                }
                let moved = hypot(value.translation.width, value.translation.height)
                if target == nil, moved > layout.cardWidth { FeedbackService.shared.play(.invalid) }
            }
    }

    /// The legal place the dragged cards overlap most; failing that, a legal place under
    /// the finger. Long runs and quick flicks land where the player meant.
    private func target(for ids: [Int], from placement: Placement, translation: CGSize, finger: CGPoint) -> Location? {
        guard !ids.isEmpty else { return nil }
        let state = model.state
        let moving = cards(ids)
        let dragged = CGRect(x: placement.point.x + translation.width, y: placement.point.y + translation.height,
                             width: layout.cardWidth, height: layout.cardHeight)
        var candidates: [(Location, CGRect)] = []
        if ids.count == 1 {
            for suit in Suit.allCases { candidates.append((.foundation(suit), layout.frame(.foundation(suit)))) }
        }
        for column in 0..<7 {
            let bottom = layout.positions(column: column, cards: state.tableau[column]).last?.y ?? layout.tableauTop
            candidates.append((.tableau(column), CGRect(x: layout.x(column: column), y: layout.tableauTop,
                                                         width: layout.cardWidth, height: bottom - layout.tableauTop + layout.cardHeight)))
        }
        let legal = candidates.filter { location, _ in
            !isSource(location, of: ids) && state.accepts(moving, at: location)
        }
        var best: (location: Location, area: CGFloat)?
        for (location, rect) in legal {
            let overlap = rect.intersection(dragged)
            guard !overlap.isNull else { continue }
            let area = overlap.width * overlap.height
            if area > 0, area > (best?.area ?? 0) { best = (location, area) }
        }
        if let best { return best.location }
        let underFinger = layout.location(at: finger, state: state, carrying: ids.count)
        return legal.first { $0.0 == underFinger }?.0
    }

    private func isSource(_ location: Location, of ids: [Int]) -> Bool {
        guard let first = ids.first else { return false }
        return model.locate(first)?.location == location
    }

    private func cards(_ ids: [Int]) -> [Card] { ids.map(Card.init(id:)) }

    /// Source and destination of the hint: the cards to move, plus the stock for a draw.
    private var hintIDs: Set<Int> {
        guard let hint = model.hint ?? model.guide else { return [] }
        switch hint {
        case .draw:
            return Set((model.state.stock.last ?? model.state.waste.first).map { [$0.id] } ?? [])
        case .move(let from, let count, let to):
            var ids: Set<Int> = []
            switch from {
            case .waste: model.state.waste.last.map { ids.insert($0.id) }
            case .foundation(let suit): model.state.foundation(suit).last.map { ids.insert($0.id) }
            case .tableau(let column): ids.formUnion(model.state.tableau[column].suffix(count).map(\.card.id))
            }
            if case .tableau(let column) = to, let last = model.state.tableau[column].last { ids.insert(last.card.id) }
            if case .foundation(let suit) = to, let last = model.state.foundation(suit).last { ids.insert(last.id) }
            return ids
        }
    }

    // MARK: Milestones

    /// A completed foundation glows and rings outward.
    @ViewBuilder
    private var foundationBurst: some View {
        if case .foundationComplete(let suit) = model.milestone, !reduceMotion {
            FoundationBurst(width: layout.cardWidth, height: layout.cardHeight, color: theme.primary)
                .offset(x: layout.frame(.foundation(suit)).minX, y: layout.frame(.foundation(suit)).minY)
                .id(suit)
        }
    }

    // MARK: Victory

    /// Cascade: each foundation card falls off the bottom, one after another.
    private func celebrationOffset(_ placement: Placement) -> CGSize {
        guard celebrating, case .foundation(let suit) = placement.area else { return .zero }
        let side: CGFloat = suit.rawValue < 2 ? -1 : 1
        return CGSize(width: side * CGFloat(13 - placement.index) * 6, height: layout.height + 200)
    }

    private func celebrationDelay(_ placement: Placement) -> Double {
        guard case .foundation(let suit) = placement.area else { return 0 }
        return Double(12 - placement.index) * 0.12 + Double(suit.rawValue) * 0.03
    }

    private func accessibilityLabel(_ card: Card, placement: Placement) -> Text {
        if !placement.isFaceUp {
            if case .stock = placement.area { return Text("Stock, \(model.state.stock.count) cards") }
            return Text("Face-down card")
        }
        let name = card.accessibilityName
        switch placement.area {
        case .waste: return Text("\(name), waste")
        case .foundation: return Text("\(name), foundation")
        case .tableau(let column): return Text("\(name), column \(column + 1)")
        case .stock: return name
        }
    }
}

extension Card {
    var accessibilityName: Text {
        let ranks: [LocalizedStringResource] = ["Ace", "2", "3", "4", "5", "6", "7", "8", "9", "10", "Jack", "Queen", "King"]
        let suits: [LocalizedStringResource] = ["spades", "hearts", "diamonds", "clubs"]
        return Text("\(Text(ranks[rank - 1])) of \(Text(suits[suit.rawValue]))")
    }
}

/// A card that turns over (180 ms around the vertical axis) when it flips.
struct FlippableCard: View {
    let card: Card
    let isFaceUp: Bool
    let deck: DeckStyle
    let back: CardBack
    let width: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        FlipEffectView(angle: isFaceUp ? 0 : 180) { showsFace in
            if showsFace {
                CardFace(card: card, deck: deck, width: width)
            } else {
                CardBackView(back: back, width: width)
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.15) : .easeInOut(duration: 0.18), value: isFaceUp)
        .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
    }
}

private struct FlipEffectView<Content: View>: View, @preconcurrency Animatable {
    var angle: Double
    @ViewBuilder let content: (Bool) -> Content

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    var body: some View {
        content(angle < 90)
            .rotation3DEffect(.degrees(angle < 90 ? angle : angle - 180), axis: (0, 1, 0), perspective: 0.4)
    }
}

/// Dashed ring of the primary, blinking twice.
private struct HintRing: View {
    let width: CGFloat
    @Environment(\.quietTheme) private var theme
    @State private var visible = true

    var body: some View {
        RoundedRectangle(cornerRadius: max(4, width * 0.1) + 3, style: .continuous)
            .strokeBorder(theme.primary, style: StrokeStyle(lineWidth: 2, dash: [5, 3]))
            .padding(-3)
            .opacity(visible ? 1 : 0)
            .task {
                for _ in 0..<3 {
                    try? await Task.sleep(for: .milliseconds(260))
                    visible.toggle()
                }
                visible = true
            }
    }
}

/// ±4 pt × 3 in 240 ms, like an invalid pair in Quiet Numbers.
private struct Shake: GeometryEffect {
    var amount: CGFloat
    var animatableData: CGFloat {
        get { amount }
        set { amount = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 4 * sin(amount * .pi * 6), y: 0))
    }
}

/// Two rings expand from a card and fade, with a soft glow, in 0.9 s.
private struct FoundationBurst: View {
    let width: CGFloat
    let height: CGFloat
    let color: Color

    @State private var expanded = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: max(4, width * 0.1) + 4, style: .continuous)
        ZStack {
            shape.fill(color.opacity(expanded ? 0 : 0.28))
            shape.strokeBorder(color, lineWidth: 2).scaleEffect(expanded ? 1.45 : 1).opacity(expanded ? 0 : 0.9)
            shape.strokeBorder(color, lineWidth: 1.5).scaleEffect(expanded ? 1.8 : 1).opacity(expanded ? 0 : 0.6)
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
        .onAppear { withAnimation(.easeOut(duration: 0.9)) { expanded = true } }
    }
}
