import QuietUI
import SwiftUI

@main
struct QuietSolitaireApp: App {
    @State private var app = AppModel(persistence: PersistenceService(store: Self.store))
    @State private var showsSplash = Self.wantsSplash
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ZStack {
                HomeView()
                    .modifier(AppearanceRoot())
                    .environment(app)
                    .task {
                        app.gameCenter.authenticate()
                        app.warmUpDaily()
                    }
                    .onChange(of: scenePhase) { _, phase in
                        if phase != .active { app.saveActiveGame() }
                    }
                if showsSplash {
                    SplashView {
                        // Reduce Motion cuts straight to Home.
                        let animation: Animation? = UIAccessibility.isReduceMotionEnabled ? nil : .easeInOut(duration: 0.25)
                        withAnimation(animation) { showsSplash = false }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
        }
    }

    /// Debug launches go straight in, so UI tests aren't held up.
    private static var wantsSplash: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return !arguments.contains("-startGame") && !arguments.contains("-uiTesting")
        #else
        return true
        #endif
    }

    /// UI tests and debug launches don't touch the player's saved games:
    /// `-startGame` keeps everything in memory; `-uiTesting` uses its own file
    /// (persists across launches, `-resetStore` wipes it).
    private static var store: PersistenceService.Store {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-startGame") { return .inMemory }
        if arguments.contains("-uiTesting") { return .named("UITests", reset: arguments.contains("-resetStore")) }
        #endif
        return .standard
    }
}
