#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: Buttons

/// Full-width capsule, 56 pt. Prominent: `primary` with `onPrimary` text;
/// otherwise `surface2` with `primary` text.
public struct CapsuleButtonStyle: ButtonStyle {
    var isProminent = true

    public init(isProminent: Bool = true) { self.isProminent = isProminent }

    @Environment(\.quietTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    public func makeBody(configuration: Configuration) -> some View {
        CapsuleButton(
            configuration: configuration,
            fill: isProminent ? theme.primary : theme.surface2,
            text: isProminent ? theme.onPrimary : theme.primary
        )
        .opacity(isEnabled ? 1 : 0.4)
    }
}

/// Smaller capsule in `accent` ("Play again" on the daily card).
public struct AccentButtonStyle: ButtonStyle {
    public init() {}

    @Environment(\.quietTheme) private var theme

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(theme.onAccent)
            .padding(.horizontal, 20)
            .frame(minHeight: 44)
            .background(theme.accent, in: Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

private struct CapsuleButton: View {
    let configuration: ButtonStyleConfiguration
    let fill: Color
    let text: Color

    public var body: some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(text)
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, 20)
            .background(fill, in: Capsule())
            .opacity(configuration.isPressed ? 0.75 : 1)
            .contentShape(Capsule())
    }
}

/// 48 pt round button on `surface` (back, more).
public struct RoundIconLabel: View {
    let systemImage: String
    var tint: Color?

    public init(systemImage: String, tint: Color? = nil) {
        self.systemImage = systemImage
        self.tint = tint
    }

    @Environment(\.quietTheme) private var theme

    public var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(tint ?? theme.ink)
            .frame(width: 48, height: 48)
            .background { SurfaceShape(shape: Circle()) }
            .contentShape(Circle())
    }
}

// MARK: Surfaces

/// `surface`, plus a 2 pt ink border in High contrast.
public struct SurfaceShape<S: InsettableShape>: View {
    let shape: S
    var fill: Color?

    public init(shape: S, fill: Color? = nil) {
        self.shape = shape
        self.fill = fill
    }

    @Environment(\.quietTheme) private var theme

    public var body: some View {
        shape
            .fill(fill ?? theme.surface)
            .overlay {
                if theme.isHighContrast {
                    shape.strokeBorder(theme.ink, lineWidth: 2)
                }
            }
    }
}

extension View {
    /// A card: `surface`, 24 pt corners.
    public func card(padding: CGFloat = 18, cornerRadius: CGFloat = 24) -> some View {
        self
            .padding(padding)
            .background { SurfaceShape(shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)) }
    }
}

// MARK: Screen chrome

extension View {
    /// Pushed screens: our own header (round back button, title, optional trailing item)
    /// instead of the navigation bar, over the theme's background.
    public func screen<Trailing: View>(
        _ title: Text? = nil,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) -> some View {
        modifier(ScreenChrome(title: title, trailing: trailing()))
    }
}

private struct ScreenChrome<Trailing: View>: ViewModifier {
    let title: Text?
    let trailing: Trailing

    @Environment(\.dismiss) private var dismiss
    @Environment(\.quietTheme) private var theme

    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            ZStack {
                if let title {
                    title
                        .font(.headline)
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)
                        .padding(.horizontal, 60)
                        .accessibilityAddTraits(.isHeader)
                }
                HStack {
                    Button { dismiss() } label: { RoundIconLabel(systemImage: "chevron.backward") }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Back", bundle: .main))
                        .accessibilityIdentifier("back")
                    Spacer()
                    trailing
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            content
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .background(theme.background)
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// Keeps the swipe-back gesture working with the navigation bar hidden.
extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1 && SwipeBack.isEnabled
    }
}

/// Screens with their own drags near the left edge (a card table) turn swipe-back off
/// while they're on screen, so the edge gesture doesn't steal them.
@MainActor
public enum SwipeBack {
    public static var isEnabled = true
}

// MARK: Segments

/// Capsule segmented control: the selected segment is `ink` with `background` text.
public struct Segments<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, title: LocalizedStringKey)]

    public init(selection: Binding<Value>, options: [(value: Value, title: LocalizedStringKey)]) {
        _selection = selection
        self.options = options
    }

    @Environment(\.quietTheme) private var theme
    @Namespace private var namespace

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(options, id: \.value) { option in
                let isSelected = option.value == selection
                Button {
                    withAnimation(.quiet) { selection = option.value }
                } label: {
                    Text(option.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .foregroundStyle(isSelected ? theme.background : theme.muted)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(theme.ink)
                                    .matchedGeometryEffect(id: "selection", in: namespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
            }
        }
        .padding(3)
        .background { SurfaceShape(shape: Capsule()) }
    }
}

// MARK: Grouped lists

/// A titled group of rows in a `surface` card, rows split by `separator` lines.
public struct GroupSection<Content: View>: View {
    let title: LocalizedStringKey?
    @ViewBuilder let content: Content

    @Environment(\.quietTheme) private var theme

    public init(_ title: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(theme.muted)
                    .padding(.horizontal, 16)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(spacing: 0) {
                Group(subviews: content) { rows in
                    ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                        row
                            .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                        if index < rows.count - 1 {
                            Rectangle()
                                .fill(theme.separator)
                                .frame(height: theme.isHighContrast ? 2 : 1)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .background { SurfaceShape(shape: RoundedRectangle(cornerRadius: 22, style: .continuous)) }
        }
    }
}

/// Switch: `primary` track when on, `surface2` when off, white knob.
public struct ThemedToggleStyle: ToggleStyle {
    public init() {}

    @Environment(\.quietTheme) private var theme

    public func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(.quiet) { configuration.isOn.toggle() }
        } label: {
            HStack {
                configuration.label
                    .foregroundStyle(theme.ink)
                Spacer()
                Capsule()
                    .fill(configuration.isOn ? theme.primary : theme.surface2)
                    .frame(width: 51, height: 31)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(.white)
                            .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                            .padding(2)
                    }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
    }
}

// MARK: Toast

/// "Long shot!": capsule with an `accent` border and a 14% `accent` fill.
public struct Toast: View {
    let text: Text

    public init(text: Text) { self.text = text }

    @Environment(\.quietTheme) private var theme

    public var body: some View {
        text
            .font(.system(.headline, design: .rounded, weight: .heavy))
            .foregroundStyle(theme.accent)
            .lineLimit(1)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(theme.accent.opacity(0.14), in: Capsule())
            .overlay { Capsule().strokeBorder(theme.accent, lineWidth: 1.5) }
    }
}
#endif
