import QuietNumbersCore
import SwiftUI

struct CellView: View {
    let cell: Cell
    let row: Int
    let column: Int
    let size: CGFloat
    let isSelected: Bool
    let isHinted: Bool
    let shakes: Int
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.appearance) private var appearance

    var body: some View {
        Button(action: action) {
            Text(verbatim: "\(cell.value)")
                .font(.boardNumber(size: size * (appearance.largerNumbers ? 0.62 : 0.5), design: appearance.numberFont.design))
                .foregroundStyle(numberStyle)
                .scaleEffect(cell.isCleared ? 0.75 : 1)
                .frame(width: size, height: size)
                .background { tile }
                .background {
                    if isSelected {
                        Circle()
                            .fill(.tint.opacity(0.22))
                            .padding(size * 0.08)
                            .transition(.opacity.combined(with: .scale(scale: 0.6)))
                    }
                }
                .overlay {
                    if isHinted {
                        Circle()
                            .strokeBorder(.tint, lineWidth: 2)
                            .padding(size * 0.08)
                            .transition(.opacity)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(cell.isCleared)
        .modifier(ShakeEffect(shakes: reduceMotion ? 0 : CGFloat(shakes)))
        .accessibilityLabel(Text("\(cell.value), row \(row + 1), column \(column + 1)"))
        .accessibilityValue(cell.isCleared ? Text("Cleared") : Text(verbatim: ""))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("cell-\(row * Board.columns + column)")
    }
}

extension CellView {
    /// Tile style from the Collection. Ghosts never get a tile.
    @ViewBuilder
    private var tile: some View {
        if !cell.isCleared {
            switch appearance.tileStyle {
            case .plain:
                EmptyView()
            case .circle:
                Circle().fill(.primary.opacity(0.07)).padding(size * 0.08)
            case .outline:
                Circle().strokeBorder(.primary.opacity(0.25), lineWidth: 1).padding(size * 0.1)
            }
        }
    }

    /// Ghosts are faint; numbers added with + are blue so the originals stand out.
    private var numberStyle: AnyShapeStyle {
        if cell.isCleared { return AnyShapeStyle(.quaternary) }
        return cell.isAdded ? AnyShapeStyle(Color.addedNumber) : AnyShapeStyle(.primary)
    }
}

/// Small horizontal shake. Animating `shakes` from n to n + 1 plays one shake.
struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 6 * sin(shakes * .pi * 6), y: 0))
    }
}
