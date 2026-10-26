import AVFoundation

/// Short tones synthesized on device (no audio files). Uses the ambient category,
/// so it respects the silent switch and mixes with the player's music.
@MainActor
final class SoundService {
    enum Event {
        case select
        case match(longShot: Bool)
        case invalid
        case rowCleared
        case boardCleared
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var cache: [String: AVAudioPCMBuffer] = [:]
    private var isConfigured = false

    func play(_ event: Event, pack: SoundPack) {
        guard configureIfNeeded() else { return }
        let notes = Self.notes(for: event)
        let key = "\(pack.rawValue)-\(notes)"
        let buffer = cache[key] ?? synthesize(notes, pack: pack)
        cache[key] = buffer
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        player.play()
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

    private func configureIfNeeded() -> Bool {
        if isConfigured { return engine.isRunning || (try? engine.start()) != nil }
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        isConfigured = true
        return (try? engine.start()) != nil
    }

    /// Notes 60 ms apart, each with a soft attack and exponential decay.
    /// Marimba adds the bar's characteristic overtone (~4×) that fades faster.
    private func synthesize(_ notes: [Double], pack: SoundPack) -> AVAudioPCMBuffer {
        let rate = format.sampleRate
        let spacing = 0.06
        let length = 0.35
        let frames = AVAudioFrameCount((Double(notes.count - 1) * spacing + length) * rate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let samples = buffer.floatChannelData![0]
        for i in 0..<Int(frames) { samples[i] = 0 }

        for (n, frequency) in notes.enumerated() {
            let start = Int(Double(n) * spacing * rate)
            for i in 0..<Int(length * rate) where start + i < Int(frames) {
                let t = Double(i) / rate
                let attack = min(t / 0.005, 1)
                var value: Double
                switch pack {
                case .soft:
                    value = sin(2 * .pi * frequency * t) * exp(-t * 14)
                case .marimba:
                    value = sin(2 * .pi * frequency * t) * exp(-t * 10)
                        + 0.35 * sin(2 * .pi * frequency * 3.9 * t) * exp(-t * 30)
                }
                samples[start + i] += Float(value * attack * 0.16)
            }
        }
        return buffer
    }
}

/// Haptics and sound together, honoring the player's settings.
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
    private let sound = SoundService()

    func play(_ event: Event) {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: PreferenceKey.hapticsEnabled) as? Bool ?? true {
            switch event {
            case .select: haptics.play(.select)
            case .match: haptics.play(.match)
            case .invalid: haptics.play(.invalid)
            case .rowCleared, .boardCleared: haptics.play(.rowCleared)
            }
        }
        if defaults.object(forKey: PreferenceKey.soundEnabled) as? Bool ?? true {
            let pack = defaults.string(forKey: PreferenceKey.soundPack).flatMap(SoundPack.init) ?? .soft
            switch event {
            case .select: sound.play(.select, pack: pack)
            case .match(let longShot): sound.play(.match(longShot: longShot), pack: pack)
            case .invalid: sound.play(.invalid, pack: pack)
            case .rowCleared: sound.play(.rowCleared, pack: pack)
            case .boardCleared: sound.play(.boardCleared, pack: pack)
            }
        }
    }
}
