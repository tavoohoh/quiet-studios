import QuietUI
import UIKit

/// Haptics and sound for play, honoring the player's settings.
@MainActor
final class FeedbackService {
    enum Event {
        case select
        /// A digit written.
        case place
        /// A row, column or box completed.
        case unitComplete
        case invalid
        case won
        case hint
    }

    static let shared = FeedbackService()

    private let haptics = HapticsService()
    private let tones = ToneService()

    func play(_ event: Event) {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: PreferenceKey.hapticsEnabled) as? Bool ?? true {
            switch event {
            case .select, .hint: haptics.play(.select)
            case .place: haptics.play(.place)
            case .unitComplete, .won: haptics.play(.success)
            case .invalid: haptics.play(.invalid)
            }
        }
        if defaults.object(forKey: PreferenceKey.soundEnabled) as? Bool ?? true {
            // C major pentatonic, like Quiet Numbers.
            switch event {
            case .select: break
            case .hint: tones.play([523.25])
            case .place: tones.play([392.0])
            case .unitComplete: tones.play([659.25, 783.99])
            case .invalid: tones.play([220.0])
            case .won: tones.play([523.25, 659.25, 783.99, 1046.5])
            }
        }
    }
}
