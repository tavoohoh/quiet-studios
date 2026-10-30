/// Points per action. Values from the brief; kept here so they're easy to tune.
public struct Scoring: Hashable, Codable, Sendable {
    public var mistake = 20
    public var hint = 10
    public var winBonus = 500

    public static let standard = Scoring()
    /// "In the Red" (hidden reward): cheaper hints in classic games only.
    public static let cheapHints = Scoring(hint: 3)

    public init(hint: Int = 10) {
        self.hint = hint
    }

    /// Each correct digit the player writes. Digits placed by a hint give nothing.
    public func points(perCell difficulty: Difficulty) -> Int {
        switch difficulty {
        case .easy: 10
        case .medium: 15
        case .hard: 20
        case .expert: 30
        }
    }

    /// Up to this time the win earns ×2; it falls to ×1 at three times as long.
    public func targetSeconds(_ difficulty: Difficulty) -> Int {
        switch difficulty {
        case .easy: 300
        case .medium: 600
        case .hard: 900
        case .expert: 1_500
        }
    }

    /// Time multiplier on a win in tenths (20 = ×2.0), so it's exact and easy to show:
    /// ×2 up to the target, down to ×1 at three times the target, in steps of 0.1.
    public func timeMultiplierTenths(forSeconds seconds: Int, difficulty: Difficulty) -> Int {
        let fastest = targetSeconds(difficulty)
        let span = Double(fastest * 2)
        let progress = min(max(Double(seconds - fastest) / span, 0), 1)
        return Int(((2 - progress) * 10 + 1e-9).rounded(.down))
    }
}
