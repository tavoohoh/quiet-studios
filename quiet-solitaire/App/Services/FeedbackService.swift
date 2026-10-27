import QuietUI
import UIKit

/// Haptics and sound for card play, honoring the player's settings.
@MainActor
final class FeedbackService {
    enum Event {
        case pickUp
        /// A card lands on a column, or the stock is drawn.
        case place
        case toFoundation
        /// A foundation reaches its king.
        case foundationComplete
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
            case .pickUp, .hint: haptics.play(.select)
            case .place, .toFoundation: haptics.play(.place)
            case .foundationComplete, .won: haptics.play(.success)
            case .invalid: haptics.play(.invalid)
            }
        }
        if defaults.object(forKey: PreferenceKey.soundEnabled) as? Bool ?? true {
            // C major pentatonic, like Quiet Numbers.
            switch event {
            case .pickUp, .hint: tones.play([523.25])
            case .place: tones.play([392.0])
            case .toFoundation: tones.play([659.25])
            case .foundationComplete: tones.play([659.25, 783.99, 1046.5])
            case .invalid: tones.play([220.0])
            case .won: tones.play([523.25, 659.25, 783.99, 1046.5])
            }
        }
    }
}
