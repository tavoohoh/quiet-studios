import UIKit

/// Haptic feedback for game events. No-op where the hardware has none (most iPads, Mac).
@MainActor
final class HapticsService {
    enum Event {
        case select
        case match
        case invalid
        case rowCleared
    }

    func play(_ event: Event) {
        switch event {
        case .select:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .match:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .invalid:
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.5)
        case .rowCleared:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }
}
