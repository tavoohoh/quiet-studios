import SwiftUI

@main
struct QuietNumbersApp: App {
    @State private var app = AppModel(persistence: PersistenceService(store: Self.store))
    @State private var showsSplash = Self.wantsSplash

    var body: some Scene {
        WindowGroup {
            ZStack {
                HomeView()
                    .modifier(AppearanceRoot())
                    .environment(app)
                    .task { app.gameCenter.authenticate() }
                if showsSplash {
                    SplashView { withAnimation(.easeOut(duration: 0.35)) { showsSplash = false } }
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
        }
        #if os(macOS)
        .defaultSize(width: 520, height: 760)
        #endif
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
