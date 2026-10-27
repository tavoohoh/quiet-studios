#if canImport(UIKit)
import SwiftUI

/// The studio's lockup for a moment on launch. Same image and background as the system
/// launch screen (`UILaunchScreen`: the app's `SplashLockup` and `LaunchBackground` assets),
/// so the hand-off is seamless. A tap skips it.
public struct SplashView: View {
    let onFinished: () -> Void

    public init(onFinished: @escaping () -> Void) {
        self.onFinished = onFinished
    }

    public var body: some View {
        Image("SplashLockup", bundle: .main)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color("LaunchBackground", bundle: .main))
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: onFinished)
            // The studio's name is a brand: never translated.
            .accessibilityLabel(Text(verbatim: "quiet studios"))
            .task {
                try? await Task.sleep(for: .seconds(1.2))
                onFinished()
            }
    }
}
#endif
