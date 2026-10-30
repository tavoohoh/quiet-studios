import QuietUI
import SwiftUI

/// The kit's friend profile on this game's boards (demo launches show sample data).
struct FriendProfileScreen: View {
    let entry: GameCenterService.Entry

    @Environment(AppModel.self) private var app

    static let boards = FriendBoards(
        daily: Leaderboard.daily.rawValue, best: Leaderboard.bestScore.rawValue, streak: Leaderboard.longestStreak.rawValue
    )

    var body: some View {
        #if DEBUG
        if DemoData.isActive {
            return AnyView(FriendProfileView(name: entry.name, load: { DemoData.headToHead(with: entry.name) }))
        }
        #endif
        return AnyView(FriendProfileView(entry: entry, gameCenter: app.gameCenter, boards: Self.boards))
    }
}

extension View {
    /// Pushes a friend's profile while `friend` is set.
    func friendProfile(_ friend: Binding<GameCenterService.Entry?>) -> some View {
        navigationDestination(isPresented: Binding(get: { friend.wrappedValue != nil }, set: { if !$0 { friend.wrappedValue = nil } })) {
            if let entry = friend.wrappedValue { FriendProfileScreen(entry: entry) }
        }
    }
}
