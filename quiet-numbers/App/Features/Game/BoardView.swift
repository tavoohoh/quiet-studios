import QuietNumbersCore
import SwiftUI

/// The grid. Rows are identified by their first cell: rows only ever leave whole,
/// so that id stays stable while the board collapses and grows.
struct BoardView: View {
    let model: GameModel
    let size: CGFloat
    let onTap: (Cell) -> Void

    private static let bottomID = "bottom"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(rows, id: \.self) { start in
                        row(startingAt: start)
                            .transition(.asymmetric(
                                insertion: .opacity,
                                removal: .opacity.combined(with: .scale(scale: 0.9, anchor: .top))
                            ))
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

    private var cells: [Cell] { model.session.board.cells }

    private var rows: [Int] {
        Array(stride(from: 0, to: cells.count, by: Board.columns))
            .map { cells[$0].id }
    }

    @ViewBuilder
    private func row(startingAt firstID: Int) -> some View {
        if let start = model.session.board.index(ofCell: firstID) {
            let end = min(start + Board.columns, cells.count)
            HStack(spacing: 0) {
                ForEach(Array(cells[start..<end].enumerated()), id: \.element.id) { offset, cell in
                    let index = start + offset
                    CellView(
                        cell: cell,
                        row: index / Board.columns,
                        column: index % Board.columns,
                        size: size,
                        isSelected: model.selectedID == cell.id,
                        isHinted: model.hintIDs.contains(cell.id),
                        shakes: model.shakes[cell.id] ?? 0,
                        action: { onTap(cell) }
                    )
                    .transition(.opacity)
                }
                Spacer(minLength: 0)
            }
            .frame(width: size * CGFloat(Board.columns))
            .id(firstID)
        }
    }

    private func rowID(containing ids: Set<Int>) -> Int? {
        guard let index = cells.firstIndex(where: { ids.contains($0.id) }) else { return nil }
        return cells[index - index % Board.columns].id
    }
}
