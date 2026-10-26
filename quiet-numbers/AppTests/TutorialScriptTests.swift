import QuietNumbersCore
import Testing
@testable import Quiet_Numbers

/// The tutorial board must play exactly as the steps say.
@Suite struct TutorialScriptTests {
    @Test func everyStepIsLegalInOrder() throws {
        var session = TutorialScript.session()
        for step in TutorialScript.steps {
            #expect(!TutorialScript.isDone(step, on: session), "step \(step.id) done too early")
            switch step.move {
            case .pair(let a, let b):
                let match = session.match(cellID: a, b)
                let outcome = try #require(match, "step \(step.id) isn't a valid pair")
                switch step.id {
                case 1, 2, 3: #expect(outcome.pair.gap == 0)
                case 4: #expect(outcome.pair.gap >= 4, "the long shot needs 4+ cleared cells between")
                case 5: #expect(outcome.pair.route == .readingOrder)
                case 6: #expect(outcome.clearedRows.count == 1)
                default: break
                }
            case .addNumbers:
                #expect(!session.hasValidPair, "the + step should come with no pairs left")
                let added = session.addNumbers()
                #expect(added)
            }
            #expect(TutorialScript.isDone(step, on: session), "step \(step.id) not detected")
        }
    }
}
