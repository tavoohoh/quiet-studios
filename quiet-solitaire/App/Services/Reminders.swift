import QuietCore
import QuietUI

/// Quiet Solitaire's texts for the kit's daily reminders (`DailyReminders`).
extension DailyReminders {
    /// Also in Info.plist (`BGTaskSchedulerPermittedIdentifiers`).
    static let friendsTaskID = "com.tavoohoh.quietsolitaire.friends"

    static func quietSolitaire() -> DailyReminders {
        DailyReminders(friendsTaskID: friendsTaskID, texts: content)
    }

    static func content(for item: DailyReminderPlan.Item, friends: FriendsToday?) -> Content {
        switch item.kind {
        case .reminder:
            let body: String
            if let friends, friends.count > 0, let name = friends.leaderName, let score = friends.leaderScore {
                let points = score.formatted()
                body = friends.count == 1
                    ? String(localized: "\(name) won today's challenge with \(points). Up for it?")
                    : String(localized: "\(friends.count) friends already played; \(name) leads with \(points).")
            } else if item.streak > 0 {
                body = String(localized: "Don't lose your \(item.streak)-day streak.")
            } else {
                body = String(localized: "Today's challenge is waiting.")
            }
            return Content(title: String(localized: "Daily Challenge"), body: body)
        case .streakAtRisk:
            return Content(title: String(localized: "Your streak"), body: String(localized: "Your \(item.streak)-day streak ends at midnight."))
        }
    }
}
