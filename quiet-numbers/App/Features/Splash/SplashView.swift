import SwiftUI

/// The studio's name for a moment on launch, over the same plain background as the
/// system launch screen so the hand-off is seamless. A tap skips it.
struct SplashView: View {
    let onFinished: () -> Void

    @State private var isShown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 10) {
            Circle()
                .fill(.tint)
                .frame(width: 10, height: 10)
                .scaleEffect(isShown ? 1 : 0.2)
            // The studio's name is a brand: never translated.
            Text(verbatim: "Quiet Studios")
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(.primary)
        }
        .opacity(isShown ? 1 : 0)
        .offset(y: isShown || reduceMotion ? 0 : 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .contentShape(Rectangle())
        .onTapGesture(perform: onFinished)
        .accessibilityElement(children: .combine)
        .task {
            withAnimation(.smooth(duration: 0.45)) { isShown = true }
            try? await Task.sleep(for: .seconds(1.3))
            onFinished()
        }
    }
}
