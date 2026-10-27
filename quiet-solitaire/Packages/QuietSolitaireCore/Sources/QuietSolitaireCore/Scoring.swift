/// Points per action. Values from the brief; kept here so they're easy to tune.
public struct Scoring: Hashable, Codable, Sendable {
    public var wasteToTableau = 5
    public var toFoundation = 10
    public var flip = 5
    public var foundationToTableau = -15
    /// No direct cost: every tap on the stock is a move, so extra passes already lower the
    /// win bonus (decided 2026-10-27; the classic −100 per pass is too harsh for draw one).
    public var recycle = 0
    public var hint = 10
    public var winBonus = 500
    /// Moves allowed before the bonus starts shrinking, and how much each extra move costs.
    public var bonusFreeMoves = 100
    public var bonusPerExtraMove = 2

    public static let standard = Scoring()
    /// "In the Red" (hidden reward): cheaper hints in classic and practice games.
    public static let cheapHints = Scoring(hint: 3)

    public init(hint: Int = 10) {
        self.hint = hint
    }

    public func bonus(forMoves moves: Int) -> Int {
        max(0, winBonus - bonusPerExtraMove * max(0, moves - bonusFreeMoves))
    }
}
