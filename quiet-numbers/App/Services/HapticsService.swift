#if canImport(UIKit)
import UIKit
#endif

/// Haptic feedback for game events. No-op where haptics aren't available (Mac).
@MainActor
final class HapticsService {
    enum Event {
        case select
        case match
        case invalid
        case rowCleared
    }

    var isEnabled = true

    func play(_ event: Event) {
        guard isEnabled else { return }
        #if os(iOS)
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
        #endif
    }
}
