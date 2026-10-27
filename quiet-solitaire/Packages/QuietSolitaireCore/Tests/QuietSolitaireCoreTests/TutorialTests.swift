import Testing
@testable import QuietSolitaireCore

/// The tutorial table must play exactly as its steps say.
@Suite struct TutorialTests {
    @Test func everyStepIsLegalAndWhereATapSendsIt() throws {
        var session = GameSession(state: Tutorial.table)
        for (index, move) in Tutorial.moves.enumerated() {
            if case .move(let from, let count, let to) = move {
                #expect(session.state.bestDestination(from: from, count: count) == to, "step \(index + 1): a tap goes elsewhere")
            }
            let played = session.play(move)
            let events = try #require(played, "step \(index + 1) isn't legal")
            let flipped = events.contains { if case .moved(_, let outcome) = $0 { outcome.flipped } else { false } }
            #expect(flipped == [3, 4, 6].contains(index + 1), "step \(index + 1) should\(flipped ? "n't" : "") turn a card over")
        }
        #expect(session.state.tableau[0].map(\.card) == [Card(13, .clubs)])
        #expect(session.state.foundation(.diamonds).count == 2)
    }
}
