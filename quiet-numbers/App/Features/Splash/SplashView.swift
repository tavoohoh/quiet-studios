import SwiftUI

/// The studio's lockup for a moment on launch. Same image and background as the system
/// launch screen (`UILaunchScreen` in project.yml), so the hand-off is seamless.
/// A tap skips it.
struct SplashView: View {
    let onFinished: () -> Void

    var body: some View {
        Image(.splashLockup)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.launchBackground))
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
