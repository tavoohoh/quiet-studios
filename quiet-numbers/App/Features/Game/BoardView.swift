import QuietNumbersCore
import SwiftUI

/// The grid. Rows are identified by their first cell: rows only ever leave whole,
/// so that id stays stable while the board collapses and grows.
struct BoardView: View {
    let model: GameModel
    let size: CGFloat
    let onTap: (Cell) -> Void

    @Environment(\.appearance) private var appearance

    private static let bottomID = "bottom"

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
                    .frame(width: size * CGFloat(Board.columns), alignment: .top)
                    .background(alignment: .topLeading) {
                        if let line = model.matchLine {
                            MatchLineView(line: line, size: size)
                                .id(line.id)
                                .transition(.asymmetric(insertion: .identity, removal: .opacity))
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        ForEach(model.pops) { pop in
                            PopView(size: size)
                                .position(x: pop.center.x * size, y: pop.center.y * size)
                        }
                    }
                    Color.clear.frame(height: size).id(Self.bottomID)
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
                        size: size,
                        isSelected: model.selectedID == cell.id || model.connectingIDs.contains(cell.id),
                        isHinted: model.hintIDs.contains(cell.id),
                        shakes: model.shakes[cell.id] ?? 0,
                        action: { onTap(cell) }
                    )
                    .transition(.opacity)
                }
                Spacer(minLength: 0)
            }
            .frame(width: size * CGFloat(Board.columns))
            .overlay {
                if model.flashingRows.contains(firstID) {
                    switch appearance.clearEffect {
                    case .outline: RowClearEffect(size: size)
                    case .wave: RowWaveEffect()
                    }
                }
            }
            .id(firstID)
        }
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
    let size: CGFloat

    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            ForEach(Array(line.segments.enumerated()), id: \.offset) { _, segment in
                SegmentShape(segment: segment, scale: size)
                    .trim(from: 0, to: progress)
                    .stroke(.tint, style: StrokeStyle(lineWidth: width, lineCap: .round))
            }
        }
        .opacity(opacity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            // Fast start, hard stop.
            withAnimation(.timingCurve(0.2, 0.9, 0.3, 1, duration: line.tier.drawDuration)) { progress = 1 }
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

/// A matched number bursting: a ring grows past the cell (`maxRing` × its side),
/// turns into an asterisk whose rays fly outwards, and fades.
private struct PopView: View {
    let size: CGFloat

    @State private var started = false

    private static let maxRing: CGFloat = 1.5
    private static let rays = 8

    private struct Values {
        var ring: CGFloat = 0.3
        var ringOpacity: Double = 1
        var burst: CGFloat = 0
        var burstOpacity: Double = 0
    }

    var body: some View {
        let duration = Pop.duration
        let grow = duration * 0.4
        Color.clear
            .frame(width: size * Self.maxRing * 1.4, height: size * Self.maxRing * 1.4)
            .keyframeAnimator(initialValue: Values(), trigger: started) { content, values in
                content.overlay {
                    Circle()
                        .stroke(.tint, lineWidth: 2)
                        .frame(width: size * values.ring, height: size * values.ring)
                        .opacity(values.ringOpacity)
                    AsteriskShape(rays: Self.rays, progress: values.burst)
                        .stroke(.tint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: size * Self.maxRing, height: size * Self.maxRing)
                        .opacity(values.burstOpacity)
                }
            } keyframes: { _ in
                KeyframeTrack(\.ring) {
                    CubicKeyframe(Self.maxRing, duration: grow)
                }
                KeyframeTrack(\.ringOpacity) {
                    LinearKeyframe(1, duration: grow)
                    LinearKeyframe(0, duration: duration * 0.1)
                }
                KeyframeTrack(\.burst) {
                    LinearKeyframe(0, duration: grow)
                    CubicKeyframe(1, duration: duration - grow)
                }
                KeyframeTrack(\.burstOpacity) {
                    LinearKeyframe(0, duration: grow)
                    LinearKeyframe(1, duration: duration * 0.05)
                    LinearKeyframe(0, duration: duration * 0.55)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear { started = true }
    }
}

/// Rays around the center, moving outwards and shortening as `progress` goes 0 → 1.
private struct AsteriskShape: Shape {
    let rays: Int
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) / 2
        let inner = radius * (0.55 + 0.45 * progress)
        let outer = radius * (0.95 + 0.25 * progress)
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
    let scale: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: segment.from.x * scale, y: segment.from.y * scale))
        path.addLine(to: CGPoint(x: segment.to.x * scale, y: segment.to.y * scale))
        return path
    }
}

/// Collection reward: a band of light sweeps across the row.
private struct RowWaveEffect: View {
    @State private var offset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in
            let band = geometry.size.width * 0.45
            LinearGradient(
                colors: [.clear, Color.accentColor.opacity(0.25), Color.accentColor.opacity(0.45), Color.accentColor.opacity(0.25), .clear],
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
                withAnimation(.easeInOut(duration: 0.24 * EffectTiming.scale)) { offset = 1 }
            }
        }
    }
}

/// Default row-clear effect: an outline that draws itself around the row.
private struct RowClearEffect: View {
    let size: CGFloat

    @State private var progress: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.35, style: .continuous).inset(by: 2)
        shape
            .trim(from: 0, to: progress)
            .stroke(.tint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .background(shape.fill(.tint.opacity(0.08 * progress)))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                if reduceMotion {
                    progress = 1
                } else {
                    withAnimation(.easeOut(duration: 0.22 * EffectTiming.scale)) { progress = 1 }
                }
            }
    }
}
