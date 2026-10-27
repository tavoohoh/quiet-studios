#if canImport(UIKit)
import AVFoundation
import UIKit

/// Haptic feedback. No-op where the hardware has none (most iPads, Mac).
@MainActor
public final class HapticsService {
    public enum Event: Sendable {
        case select
        /// A piece lands: a pair, a card.
        case place
        case success
        case invalid
    }

    public init() {}

    public func play(_ event: Event) {
        switch event {
        case .select: UISelectionFeedbackGenerator().selectionChanged()
        case .place: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .invalid: UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
    }
}

/// Short tones synthesized on device (no audio files). Uses the ambient category,
/// so it respects the silent switch and mixes with the player's music.
@MainActor
public final class ToneService {
    public enum Voice: String, Sendable {
        case soft
        /// Adds the bar's characteristic overtone (~4×) that fades faster.
        case marimba
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var cache: [String: AVAudioPCMBuffer] = [:]
    private var isConfigured = false

    public init() {}

    /// Frequencies (Hz) played 60 ms apart.
    public func play(_ notes: [Double], voice: Voice = .soft) {
        guard !notes.isEmpty, configureIfNeeded() else { return }
        let key = "\(voice.rawValue)-\(notes)"
        let buffer = cache[key] ?? synthesize(notes, voice: voice)
        cache[key] = buffer
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        player.play()
    }

    private func configureIfNeeded() -> Bool {
        if isConfigured { return engine.isRunning || (try? engine.start()) != nil }
        try? AVAudioSession.sharedInstance().setCategory(.ambient)
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        isConfigured = true
        return (try? engine.start()) != nil
    }

    /// Each note with a soft attack and exponential decay.
    private func synthesize(_ notes: [Double], voice: Voice) -> AVAudioPCMBuffer {
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
                let value = switch voice {
                case .soft:
                    sin(2 * .pi * frequency * t) * exp(-t * 14)
                case .marimba:
                    sin(2 * .pi * frequency * t) * exp(-t * 10) + 0.35 * sin(2 * .pi * frequency * 3.9 * t) * exp(-t * 30)
                }
                samples[start + i] += Float(value * attack * 0.16)
            }
        }
        return buffer
    }
}
#endif
