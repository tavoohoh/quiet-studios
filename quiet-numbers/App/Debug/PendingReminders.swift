#if DEBUG
import QuietUI
import SwiftUI

/// `-showReminders` (UI tests): the daily notifications waiting in the system, under
/// Settings, refreshed every half second.
struct PendingReminders: View {
    static var isRequested: Bool { ProcessInfo.processInfo.arguments.contains("-showReminders") }

    @Environment(AppModel.self) private var app
    @State private var lines: [String] = []

    var body: some View {
        Text(lines.isEmpty ? "none" : lines.joined(separator: "\n"))
            .font(.caption2.monospaced())
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("pendingReminders")
            .task {
                while !Task.isCancelled {
                    lines = await app.reminders.pendingDescriptions()
                    try? await Task.sleep(for: .milliseconds(500))
                }
            }
    }
}
#endif
