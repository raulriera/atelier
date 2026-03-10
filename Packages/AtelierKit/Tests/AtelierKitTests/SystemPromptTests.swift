import Foundation
import Testing
@testable import AtelierKit

@Suite("SystemPrompt")
struct SystemPromptTests {

    @Test("Core instructions are not empty")
    func coreInstructionsNotEmpty() {
        #expect(!SystemPrompt.coreInstructions.isEmpty)
    }

    @Test("Core instructions mention EnterPlanMode")
    func mentionsEnterPlanMode() {
        #expect(SystemPrompt.coreInstructions.contains("EnterPlanMode"))
    }

    @Test("Core instructions mention ExitPlanMode")
    func mentionsExitPlanMode() {
        #expect(SystemPrompt.coreInstructions.contains("ExitPlanMode"))
    }

    @Test("Core instructions require waiting for user approval")
    func requiresApproval() {
        #expect(SystemPrompt.coreInstructions.contains("wait"))
        #expect(SystemPrompt.coreInstructions.contains("approve"))
    }

    @Test("Core instructions steer toward non-technical language")
    func steersNonTechnical() {
        #expect(SystemPrompt.coreInstructions.contains("non-technical"))
    }

    @Test("Core instructions reference project context files")
    func referencesContextFiles() {
        #expect(SystemPrompt.coreInstructions.contains("context file"))
    }

    @Test("Current date contains today's date")
    func currentDateContainsToday() {
        let date = SystemPrompt.currentDate
        #expect(date.hasPrefix("Today is "))
        #expect(date.hasSuffix("."))
        // Should contain the current year
        let year = Calendar.current.component(.year, from: Date())
        #expect(date.contains(String(year)))
    }
}
