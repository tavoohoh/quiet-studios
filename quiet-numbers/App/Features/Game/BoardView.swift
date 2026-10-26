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
