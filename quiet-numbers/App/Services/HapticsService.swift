import UIKit

/// Haptic feedback for game events. No-op where the hardware has none (most iPads, Mac).
@MainActor
final class HapticsService {
    enum Event {
        case select
        case match
        /// Also a long shot and a cleared row.
        case success
        case invalid
    }

    func play(_ event: Event) {
        switch event {
        case .select:
            UISelectionFeedbackGenerator().selectionChanged()
        case .match:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .success:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .invalid:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}
