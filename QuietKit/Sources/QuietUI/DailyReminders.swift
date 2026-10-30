#if canImport(UIKit)
import BackgroundTasks
import QuietCore
import SwiftUI
import UserNotifications

/// Local notifications for the daily challenge (no server, no push): the 19:00 reminder and
/// the 21:00 "streak at risk", planned by `DailyReminderPlan`. Each app gives the texts and
/// tells it where the day stands; the kit schedules, cancels and rewrites.
///
/// Friends: a background refresh from 17:00 loads today's friends board (Game Center) and
/// rewrites the pending 19:00 text ("Ana won it with 560"). Nothing from Game Center is
/// stored; the text just replaces the one waiting in the system.
///
/// The app wires it up with:
/// - `state`: whether today's daily is completed and the current streak;
/// - `reschedule()` on launch, on becoming active, after a daily is completed, and on
///   `.NSCalendarDayChanged` / `.NSSystemTimeZoneDidChange` (`.dailyReminderTriggers`);
/// - `.backgroundTask(.appRefresh(friendsTaskID)) { await reminders.refreshFriends(…) }`,
///   with `friendsTaskID` in `BGTaskSchedulerPermittedIdentifiers` and the `fetch` mode;
/// - `.dailyReminderOffer(…)` after a first completed daily, and `DailyReminderToggle` in
///   Settings.
@MainActor
@Observable
public final class DailyReminders {
    /// A notification's text, from the app's catalog.
    public struct Content: Sendable {
        public var title: String
        public var body: String

        public init(title: String, body: String) {
            self.title = title
            self.body = body
        }
    }

    /// Text for a planned item; `friends` only for today's reminder once the background
    /// refresh found friends who played.
    public typealias Texts = @MainActor (DailyReminderPlan.Item, FriendsToday?) -> Content

    /// Where the day stands, asked each time the plan is made.
    public var state: @MainActor () -> (todayCompleted: Bool, streak: Int) = { (false, 0) }
    /// The app's clock (a fixed date in debug launches).
    public var clock: @MainActor () -> Date = { .now }

    public private(set) var authorization: UNAuthorizationStatus = .notDetermined
    /// The Settings switch. Off: nothing is scheduled.
    public private(set) var isEnabled: Bool
    /// The in-context offer was already shown (whatever the answer).
    public private(set) var wasOffered: Bool

    /// The `BGAppRefreshTask` identifier (also in the app's Info.plist).
    public let friendsTaskID: String
    private let texts: Texts
    private let defaults: UserDefaults
    private let center = UNUserNotificationCenter.current()

    /// The background refresh starts from this hour (iOS decides when it actually runs).
    public static let friendsHour = 17
    static let enabledKey = "dailyReminders.enabled"
    static let offeredKey = "dailyReminders.offered"

    public init(friendsTaskID: String, defaults: UserDefaults = .standard, texts: @escaping Texts) {
        self.friendsTaskID = friendsTaskID
        self.defaults = defaults
        self.texts = texts
        isEnabled = defaults.object(forKey: Self.enabledKey) as? Bool ?? true
        wasOffered = defaults.bool(forKey: Self.offeredKey)
    }

    /// Notifications are allowed and the switch is on.
    public var isActive: Bool { isEnabled && authorization.allowsDelivery }

    /// Worth offering after a completed daily: never offered, and the system hasn't asked yet.
    public var shouldOffer: Bool { !wasOffered && authorization == .notDetermined }

    public func refreshAuthorization() async {
        authorization = await center.notificationSettings().authorizationStatus
    }

    /// The system prompt (only shown once by iOS). Turns the switch on if granted.
    @discardableResult
    public func requestAuthorization() async -> Bool {
        markOffered()
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await refreshAuthorization()
        if granted { setEnabledFlag(true) }
        await reschedule()
        return granted
    }

    /// "Not now" on the offer: it won't be shown again (Settings still has the switch).
    public func markOffered() {
        wasOffered = true
        defaults.set(true, forKey: Self.offeredKey)
    }

    public func setEnabled(_ enabled: Bool) async {
        setEnabledFlag(enabled)
        if enabled, authorization == .notDetermined {
            await requestAuthorization()
        } else {
            await reschedule()
        }
    }

    private func setEnabledFlag(_ enabled: Bool) {
        isEnabled = enabled
        defaults.set(enabled, forKey: Self.enabledKey)
    }

    // MARK: Scheduling

    /// Replaces every pending daily notification with a fresh plan (or none).
    public func reschedule(now: Date? = nil) async {
        let now = now ?? clock()
        await refreshAuthorization()
        let pending = await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix("daily.") }
        center.removePendingNotificationRequests(withIdentifiers: pending)
        guard isActive else { return }
        let (todayCompleted, streak) = state()
        for item in DailyReminderPlan.items(now: now, todayCompleted: todayCompleted, streak: streak) {
            try? await center.add(request(for: item, friends: nil))
        }
        scheduleFriendsRefresh(now: now)
    }

    /// Today's reminder, rewritten with what friends did (if it's still pending).
    public func rewriteToday(with friends: FriendsToday, now: Date? = nil) async {
        let now = now ?? clock()
        guard isActive, friends.count > 0 else { return }
        let (todayCompleted, streak) = state()
        let today = DailyKey.dayKey(for: now)
        guard let item = DailyReminderPlan.items(now: now, todayCompleted: todayCompleted, streak: streak)
            .first(where: { $0.dayKey == today && $0.kind == .reminder }) else { return }
        // Same identifier: the new request replaces the pending one.
        try? await center.add(request(for: item, friends: friends))
    }

    /// The background task's work: `load` gets today's friends (`GameCenterService.friendsToday`).
    public func refreshFriends(now: Date? = nil, load: @MainActor () async -> FriendsToday?) async {
        let now = now ?? clock()
        scheduleFriendsRefresh(now: now.addingTimeInterval(60))
        if let friends = await load() { await rewriteToday(with: friends, now: now) }
    }

    /// The daily notifications waiting in the system, for QA: "id · day hour · body".
    public func pendingDescriptions() async -> [String] {
        await center.pendingNotificationRequests()
            .filter { $0.identifier.hasPrefix("daily.") }
            .sorted { $0.identifier < $1.identifier }
            .map { request in
                let hour = (request.trigger as? UNCalendarNotificationTrigger)?.dateComponents.hour ?? -1
                return "\(request.identifier) · \(hour):00 · \(request.content.body)"
            }
    }

    private func request(for item: DailyReminderPlan.Item, friends: FriendsToday?) -> UNNotificationRequest {
        let text = texts(item, friends)
        let content = UNMutableNotificationContent()
        content.title = text.title
        content.body = text.body
        content.sound = .default
        content.threadIdentifier = "daily"
        let trigger = UNCalendarNotificationTrigger(dateMatching: item.components, repeats: false)
        return UNNotificationRequest(identifier: item.identifier, content: content, trigger: trigger)
    }

    /// Next run from `friendsHour` today, or tomorrow once today's reminder time has passed.
    private func scheduleFriendsRefresh(now: Date) {
        let calendar = Calendar.current
        var start = calendar.date(bySettingHour: Self.friendsHour, minute: 0, second: 0, of: now) ?? now
        if calendar.component(.hour, from: now) >= DailyReminderPlan.reminderHour {
            start = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        }
        let request = BGAppRefreshTaskRequest(identifier: friendsTaskID)
        request.earliestBeginDate = max(start, now)
        try? BGTaskScheduler.shared.submit(request)
    }
}

private extension UNAuthorizationStatus {
    var allowsDelivery: Bool {
        switch self {
        case .authorized, .provisional, .ephemeral: true
        default: false
        }
    }
}

// MARK: - Triggers

public extension View {
    /// Plans again when the day or the time zone changes, and when the app becomes active.
    func dailyReminderTriggers(_ reminders: DailyReminders) -> some View {
        modifier(ReminderTriggers(reminders: reminders))
    }

    /// The in-context question after a completed daily: "Remind you at 7 p.m.?". Asked once;
    /// "Not now" leaves the Settings switch to change it later.
    func dailyReminderOffer(_ reminders: DailyReminders, isPresented: Binding<Bool>) -> some View {
        modifier(ReminderOffer(reminders: reminders, isPresented: isPresented))
    }
}

private struct ReminderTriggers: ViewModifier {
    let reminders: DailyReminders

    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .task { await reminders.reschedule() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await reminders.reschedule() } }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                Task { await reminders.reschedule() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
                Task { await reminders.reschedule() }
            }
    }
}

/// An hour in the device's format ("7 PM", "19:00").
func reminderTime(_ hour: Int = DailyReminderPlan.reminderHour) -> Text {
    let date = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
    return Text(date, format: .dateTime.hour())
}

private struct ReminderOffer: ViewModifier {
    let reminders: DailyReminders
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        content.alert(Text("Remind you at \(reminderTime())?", bundle: .main), isPresented: $isPresented) {
            Button {
                Task { await reminders.requestAuthorization() }
            } label: {
                Text("Remind me", bundle: .main)
            }
            Button(role: .cancel) {
                reminders.markOffered()
            } label: {
                Text("Not now", bundle: .main)
            }
        } message: {
            Text("Only on days you haven't played the challenge yet. You can change it in Settings.", bundle: .main)
        }
    }
}

// MARK: - Settings

/// "Daily challenge reminder" switch for a Settings section. Turning it on asks for
/// permission the first time; if notifications are off for the app, it points to Settings.
public struct DailyReminderToggle: View {
    let reminders: DailyReminders

    @Environment(\.quietTheme) private var theme
    @Environment(\.openURL) private var openURL

    public init(reminders: DailyReminders) {
        self.reminders = reminders
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: Binding(
                get: { reminders.isActive },
                set: { on in Task { await reminders.setEnabled(on) } }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily challenge reminder", bundle: .main)
                        .foregroundStyle(theme.ink)
                    Text("At \(reminderTime()) if you haven't played; with a streak of 3 or more, another at \(reminderTime(DailyReminderPlan.streakHour)).", bundle: .main)
                        .font(.subheadline)
                        .foregroundStyle(theme.muted)
                }
            }
            .toggleStyle(ThemedToggleStyle())
            .disabled(reminders.authorization == .denied)
            if reminders.authorization == .denied {
                Button {
                    if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                } label: {
                    Text("Notifications are off for this app. Turn them on in Settings.", bundle: .main)
                        .font(.footnote)
                        .foregroundStyle(theme.primary)
                        .multilineTextAlignment(.leading)
                }
                .buttonStyle(.plain)
            }
        }
        .task { await reminders.refreshAuthorization() }
    }
}
#endif
