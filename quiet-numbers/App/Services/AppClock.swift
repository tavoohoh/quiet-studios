import Foundation

/// "Now" for anything the player sees dated: today's challenge, the calendar, the countdown.
/// The real clock, except in DEBUG demo launches, which freeze it so screenshots match.
enum AppClock {
    static var now: Date {
        #if DEBUG
        if let date = DemoData.date { return date }
        #endif
        return .now
    }
}
