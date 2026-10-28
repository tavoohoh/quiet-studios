import QuietNumbersCore
import QuietUI
import SwiftUI

/// The grid. Rows are identified by their first cell: rows only ever leave whole,
/// so that id stays stable while the board collapses and grows.
/// Numbers can be tapped one after the other, or dragged from one to the other.
struct BoardView: View {
    let model: GameModel
    /// One cell: a ninth of the board's width, by the row height.
    let cell: CGSize
    let onTap: (Cell) -> Void
    /// A drag started on this number (it becomes the selection).
    let onDragStart: (Cell) -> Void

    @Environment(\.appearance) private var appearance

    @Environment(\.quietTheme) private var theme
    /// The number a drag started on, and where the finger is (in the grid's space).
    @State private var dragFromID: Int?
    @State private var dragLocation: CGPoint?

    private static let bottomID = "bottom"
    private static let gridSpace = "grid"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 0) {
                        ForEach(rows, id: \.self) { start in
                            row(startingAt: start)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .offset(y: 12)),
                                    removal: .opacity.combined(with: .scale(scale: 0.6))
                                ))
                        }
                    }
                    .frame(width: cell.width * CGFloat(Board.columns), alignment: .top)
                    .coordinateSpace(name: Self.gridSpace)
                    .overlay(alignment: .topLeading) { dragLine }
                    .background(alignment: .topLeading) {
                        if let line = model.matchLine {
                            MatchLineView(line: line, cell: cell)
                                .id(line.id)
                                .transition(.asymmetric(insertion: .identity, removal: .opacity))
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        ForEach(model.pops) { pop in
                            PopView(pop: pop, scale: cell.height / 46)
                                .position(x: pop.center.x * cell.width, y: pop.center.y * cell.height)
                        }
                        if let points = model.floatingPoints {
                            FloatingPointsView(points: points, cell: cell) { model.dismissFloatingPoints(points) }
                                .id(points.id)
                        }
                    }
                    Color.clear.frame(height: cell.height).id(Self.bottomID)
                }
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            .onChange(of: model.additions) {
                withAnimation(.quiet) { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
            }
            .onChange(of: model.hintIDs) {
                guard let rowID = rowID(containing: model.hintIDs) else { return }
                withAnimation(.quiet) { proxy.scrollTo(rowID, anchor: .center) }
            }
        }
    }

    private var cells: [Cell] { model.board.cells }

    private var rows: [Int] {
        Array(stride(from: 0, to: cells.count, by: Board.columns))
            .map { cells[$0].id }
    }

    @ViewBuilder
    private func row(startingAt firstID: Int) -> some View {
        if let start = model.board.index(ofCell: firstID) {
            let end = min(start + Board.columns, cells.count)
            HStack(spacing: 0) {
                ForEach(Array(cells[start..<end].enumerated()), id: \.element.id) { offset, cell in
                    let index = start + offset
                    CellView(
                        cell: cell,
                        row: index / Board.columns,
                        column: index % Board.columns,
                        size: self.cell,
                        isSelected: model.selectedID == cell.id || model.connectingIDs.contains(cell.id),
                        isMissed: model.missIDs.contains(cell.id),
                        isHinted: model.hintIDs.contains(cell.id),
                        hintNudges: model.guideNudges,
                        shakes: model.shakes[cell.id] ?? 0,
                        entranceDelay: entranceDelay(for: cell),
                        action: { onTap(cell) }
                    )
                    .highPriorityGesture(drag(from: cell), including: cell.isCleared ? .subviews : .all)
                    .transition(.opacity)
                }
                Spacer(minLength: 0)
            }
            .frame(width: self.cell.width * CGFloat(Board.columns))
            .overlay {
                if model.flashingRows.contains(firstID) {
                    switch appearance.clearEffect {
                    case .outline: RowClearEffect(height: self.cell.height)
                    case .wave: RowWaveEffect()
                    }
                }
            }
            .id(firstID)
        }
    }

    // MARK: Dragging

    private func drag(from cell: Cell) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .named(Self.gridSpace))
            .onChanged { value in
                if dragFromID != cell.id {
                    dragFromID = cell.id
                    onDragStart(cell)
                }
                dragLocation = value.location
            }
            .onEnded { value in
                dragFromID = nil
                dragLocation = nil
                guard let target = self.cell(at: value.location), target.id != cell.id, !target.isCleared else { return }
                onTap(target)
            }
    }

    /// The board cell under a point of the grid, if any.
    private func cell(at point: CGPoint) -> Cell? {
        guard point.x >= 0, point.y >= 0, point.x < cell.width * CGFloat(Board.columns) else { return nil }
        let index = Int(point.y / cell.height) * Board.columns + Int(point.x / cell.width)
        return cells.indices.contains(index) ? cells[index] : nil
    }

    /// From the dragged number to the finger, under the numbers' rings.
    @ViewBuilder
    private var dragLine: some View {
        if let id = dragFromID, let location = dragLocation, let index = model.board.index(ofCell: id) {
            let start = CGPoint(
                x: (CGFloat(index % Board.columns) + 0.5) * cell.width,
                y: (CGFloat(index / Board.columns) + 0.5) * cell.height
            )
            Path { path in
                path.move(to: start)
                path.addLine(to: location)
            }
            .stroke(theme.primary.opacity(0.5), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    /// Numbers from the last + come in one by one: 25 ms apart, all within 1.2 s.
    private func entranceDelay(for cell: Cell) -> Double? {
        guard let first = model.addedFromID, cell.id >= first else { return nil }
        return min(Double(cell.id - first) * 0.025, 1.2 - 0.16) * EffectTiming.scale
    }

    private func rowID(containing ids: Set<Int>) -> Int? {
        guard let index = cells.firstIndex(where: { ids.contains($0.id) }) else { return nil }
        return cells[index - index % Board.columns].id
    }
}

/// The line between a matched pair. Grows in, then fades out with the ghosts.
/// Solid, in the theme's accent; thicker the farther apart the numbers are.
private struct MatchLineView: View {
    let line: MatchLine
    let cell: CGSize

    @Environment(\.quietTheme) private var theme

    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            ForEach(Array(line.segments.enumerated()), id: \.offset) { _, segment in
                SegmentShape(segment: segment, scale: cell)
                    .trim(from: 0, to: progress)
                    .stroke(theme.primary, style: StrokeStyle(lineWidth: width, lineCap: .round))
            }
        }
        .opacity(opacity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            withAnimation(.easeOut(duration: line.tier.drawDuration)) { progress = 1 }
        }
    }

    private var width: CGFloat {
        switch line.tier {
        case .subtle: 2
        case .medium: 3
        case .dramatic: 4
        }
    }

    private var opacity: Double {
        line.tier == .subtle ? 0.6 : 1
    }
}

/// A matched number bursting: 8 rays move out from 15 to 25 pt and fade
/// (accent for a long shot, primary otherwise).
private struct PopView: View {
    let pop: Pop
    /// 1 at the 46 pt row height.
    let scale: CGFloat

    @Environment(\.quietTheme) private var theme
    @State private var progress: CGFloat = 0

    private static let rays = 8

    var body: some View {
        AsteriskShape(rays: Self.rays, progress: progress)
            .stroke(pop.isLongShot ? theme.accent : theme.primary,
                    style: StrokeStyle(lineWidth: 2.5 * scale, lineCap: .round))
            .frame(width: 54 * scale, height: 54 * scale)
            .opacity(1 - progress)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                withAnimation(.easeOut(duration: Pop.duration)) { progress = 1 }
            }
    }
}

/// Rays around the center, 10 pt long (at 54 pt across), moving outwards as `progress` goes 0 → 1.
private struct AsteriskShape: Shape {
    let rays: Int
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let unit = min(rect.width, rect.height) / 54
        let inner = (15 + 10 * progress - 5) * unit
        let outer = inner + 10 * unit
        var path = Path()
        for ray in 0..<rays {
            let angle = Double(ray) / Double(rays) * 2 * .pi
            let direction = CGPoint(x: cos(angle), y: sin(angle))
            path.move(to: CGPoint(x: rect.midX + direction.x * inner, y: rect.midY + direction.y * inner))
            path.addLine(to: CGPoint(x: rect.midX + direction.x * outer, y: rect.midY + direction.y * outer))
        }
        return path
    }
}

private struct SegmentShape: Shape {
    let segment: MatchLine.Segment
    let scale: CGSize

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: segment.from.x * scale.width, y: segment.from.y * scale.height))
        path.addLine(to: CGPoint(x: segment.to.x * scale.width, y: segment.to.y * scale.height))
        return path
    }
}

/// Collection reward: a band of light sweeps across the row.
private struct RowWaveEffect: View {
    @State private var offset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.quietTheme) private var theme

    var body: some View {
        GeometryReader { geometry in
            let band = geometry.size.width * 0.45
            LinearGradient(
                colors: [.clear, theme.primary.opacity(0.25), theme.primary.opacity(0.45), theme.primary.opacity(0.25), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: band)
            .offset(x: offset * (geometry.size.width + band) - band)
        }
        .clipShape(Capsule())
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            if reduceMotion {
                offset = 0.5
            } else {
                withAnimation(.easeInOut(duration: 0.15 * EffectTiming.scale)) { offset = 1 }
            }
        }
    }
}

/// Default row-clear effect: the row lights up while an outline draws itself around it.
private struct RowClearEffect: View {
    let height: CGFloat

    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.quietTheme) private var theme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: height * 0.35, style: .continuous).inset(by: 2)
        shape
            .trim(from: 0, to: progress)
            .stroke(theme.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .background(shape.fill(theme.primary.opacity(0.14 * progress)))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                if reduceMotion {
                    progress = 1
                } else {
                    withAnimation(.easeOut(duration: 0.15 * EffectTiming.scale)) { progress = 1 }
                }
            }
    }
}
