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

    var body: some View {
        Button(action: action) {
            Text(verbatim: "\(cell.value)")
                .font(.boardNumber(size: size * 0.5))
                .foregroundStyle(numberStyle)
                .scaleEffect(cell.isCleared ? 0.85 : 1)
                .frame(width: size, height: size)
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
    /// Ghosts are faint; numbers added with + use the accent so the originals stand out.
    private var numberStyle: AnyShapeStyle {
        if cell.isCleared { return AnyShapeStyle(.quaternary) }
        return cell.isAdded ? AnyShapeStyle(.tint) : AnyShapeStyle(.primary)
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
        ProjectionTransform(CGAffineTransform(translationX: 4 * sin(shakes * .pi * 4), y: 0))
    }
}
