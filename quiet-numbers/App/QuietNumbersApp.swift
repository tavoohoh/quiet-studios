import SwiftUI

@main
struct QuietNumbersApp: App {
    @State private var app = AppModel(persistence: PersistenceService(store: Self.store))

    var body: some Scene {
        WindowGroup {
            HomeView()
                .modifier(AppearanceRoot())
                .environment(app)
        }
        #if os(macOS)
        .defaultSize(width: 520, height: 760)
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
