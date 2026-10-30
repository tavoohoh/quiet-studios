import Foundation
import Testing
@testable import Quiet_Solitaire

/// "New Game" tapped again while the solver looks for a winnable deal (reported 2026-10-30:
/// several games opened).
@MainActor
@Suite struct NewGameTests {
    @Test func repeatedTapsDealOnce() async {
        let app = AppModel(persistence: PersistenceService(store: .inMemory))
        async let first = app.newClassic()
        async let second = app.newClassic()
        async let third = app.newClassic()
        let started = await [first, second, third].filter { $0 }
        #expect(started.count == 1)
        #expect(app.activeGame != nil && !app.isPreparing)
        // Once it's done, the next tap deals again.
        #expect(await app.newClassic())
    }
}
