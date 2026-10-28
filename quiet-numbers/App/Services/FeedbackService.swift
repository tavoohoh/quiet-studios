import QuietUI
import UIKit

/// The game's haptics and sounds, on the kit's `HapticsService` and `ToneService`,
/// honoring the player's settings and sound pack.
@MainActor
final class FeedbackService {
    enum Event {
        case select
        case match(longShot: Bool)
        case invalid
        case rowCleared
        case boardCleared
    }

    static let shared = FeedbackService()

    private let haptics = HapticsService()
    private let tones = ToneService()

    func play(_ event: Event) {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: PreferenceKey.hapticsEnabled) as? Bool ?? true {
            switch event {
            case .select: haptics.play(.select)
            case .match(let longShot): haptics.play(longShot ? .success : .place)
            case .invalid: haptics.play(.invalid)
            case .rowCleared, .boardCleared: haptics.play(.success)
            }
        }
        if defaults.object(forKey: PreferenceKey.soundEnabled) as? Bool ?? true {
            let pack = defaults.string(forKey: PreferenceKey.soundPack).flatMap(SoundPack.init) ?? .soft
            tones.play(Self.notes(for: event), voice: pack.voice)
        }
    }

    /// Frequencies (Hz) played one after another, on a C major pentatonic scale.
    private static func notes(for event: Event) -> [Double] {
        switch event {
        case .select: [523.25]
        case .match(let longShot): longShot ? [659.25, 987.77] : [659.25]
        case .invalid: [220.0]
        case .rowCleared: [523.25, 659.25, 783.99]
        case .boardCleared: [523.25, 659.25, 783.99, 1046.5]
        }
    }
}

extension SoundPack {
    /// The kit's synthesizer voice for this pack.
    var voice: ToneService.Voice {
        switch self {
        case .soft: .soft
        case .marimba: .marimba
        }
    }
}
