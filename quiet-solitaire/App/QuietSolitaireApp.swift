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
                        app.warmUpClassic()
                        #if DEBUG
                        // `-refreshFriends`: run the background refresh now (UI tests, QA).
                        if ProcessInfo.processInfo.arguments.contains("-refreshFriends") {
                            await app.reminders.reschedule()
                            await app.refreshFriendsReminder()
                        }
                        #endif
                    }
                    .onChange(of: scenePhase) { _, phase in
                        if phase != .active { app.saveActiveGame() }
                    }
                    .dailyReminderTriggers(app.reminders)
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
        // From 17:00: what friends did today goes into the 19:00 reminder.
        .backgroundTask(.appRefresh(DailyReminders.friendsTaskID)) {
            await app.refreshFriendsReminder()
        }
    }

    /// Debug launches go straight in, so UI tests aren't held up.
    private static var wantsSplash: Bool {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        return !arguments.contains("-startGame") && !arguments.contains("-uiTesting") && !arguments.contains("-demo")
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
        if arguments.contains("-startGame") || arguments.contains("-demo") { return .inMemory }
        if arguments.contains("-uiTesting") { return .named("UITests", reset: arguments.contains("-resetStore")) }
        #endif
        return .standard
    }
}
