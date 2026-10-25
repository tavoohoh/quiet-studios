import SwiftUI

@main
struct QuietNumbersApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        #if os(macOS)
        .defaultSize(width: 520, height: 760)
        #endif
    }
}
