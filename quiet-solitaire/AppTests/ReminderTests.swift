import Foundation
import QuietCore
import QuietSolitaireCore
import QuietUI
import Testing
@testable import Quiet_Solitaire

/// The daily reminders as this app uses them (the plan itself is tested in QuietKit).
@MainActor
@Suite struct ReminderTests {
    private func reminders() -> DailyReminders {
        DailyReminders(friendsTaskID: "test", defaults: UserDefaults(suiteName: UUID().uuidString)!, texts: DailyReminders.content)
    }

    private func todaysReminder(streak: Int) -> DailyReminderPlan.Item {
        let morning = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: .now)!
        return DailyReminderPlan.items(now: morning, todayCompleted: false, streak: streak).first { $0.kind == .reminder }!
    }

    @Test func textsFollowStreakAndFriends() {
        let plain = DailyReminders.content(for: todaysReminder(streak: 1), friends: nil)
        #expect(plain.body == String(localized: "Today's challenge is waiting."))
        let streak = DailyReminders.content(for: todaysReminder(streak: 8), friends: nil)
        #expect(streak.body.contains("8"))
        let one = DailyReminders.content(for: todaysReminder(streak: 8), friends: FriendsToday(count: 1, leaderName: "Ana", leaderScore: 560))
        #expect(one.body.contains("Ana") && one.body.contains("560"))
        let many = DailyReminders.content(for: todaysReminder(streak: 0), friends: FriendsToday(count: 3, leaderName: "Ana", leaderScore: 560))
        #expect(many.body.contains("3") && many.body.contains("Ana"))
    }

    @Test func friendsSummarySkipsThePlayer() {
        let friends = FriendsToday(entries: DemoData.friendsEntries)
        #expect(friends.count == 3)
        #expect(friends.leaderName == "vale")
    }

    @Test func aCompletedDailyOffersTheReminderOnce() {
        let app = AppModel(persistence: PersistenceService(store: .inMemory), reminders: reminders())
        let today = app.todayKey
        app.persistence.startDaily(today)
        let foundations = Suit.allCases.map { suit in (1...(suit == .spades ? 12 : 13)).map { Card($0, suit) } }
        let state = GameState(stock: [], waste: [Card(13, .spades)], foundations: foundations, tableau: Array(repeating: [], count: 7))
        let model = GameModel(session: GameSession(mode: .daily(dayKey: today), state: state))
        app.start(model, as: .daily(dayKey: today))
        model.tap(Card(13, .spades).id)
        #expect(!app.offersReminders)
        app.leftGame()
        #expect(app.offersReminders)
        app.offersReminders = false
        app.reminders.markOffered()
        // A classic game never offers it.
        app.leftGame()
        #expect(!app.offersReminders)
    }
}
