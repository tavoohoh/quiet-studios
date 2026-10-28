import Foundation

/// "Now" for anything the player sees dated: today's challenge, the calendar, the countdown.
/// The real clock, except in DEBUG with `-date yyyy-MM-ddTHH:mm:ssZ` (QA).
enum AppClock {
    static var now: Date {
        #if DEBUG
        if let date = DemoData.date { return date }
        let arguments = ProcessInfo.processInfo.arguments
        if let i = arguments.firstIndex(of: "-date"), i + 1 < arguments.count,
           let date = ISO8601DateFormatter().date(from: arguments[i + 1]) {
            return date
        }
        #endif
        return .now
    }
}
