import Foundation

/// "05:16", or "1:05:16" past an hour.
enum GameClock {
    static func string(_ seconds: Int) -> String {
        let duration = Duration.seconds(seconds)
        return seconds >= 3600
            ? duration.formatted(.time(pattern: .hourMinuteSecond))
            : duration.formatted(.time(pattern: .minuteSecond(padMinuteToLength: 2)))
    }
}
