import Testing
@testable import AtelierKit

@Suite("AtelierPrompt")
struct AtelierPromptTests {

    @Test("Core instructions are not empty")
    func coreInstructionsNotEmpty() {
        #expect(!AtelierPrompt.coreInstructions.isEmpty)
    }

    @Test("Core instructions mention EnterPlanMode")
    func mentionsEnterPlanMode() {
        #expect(AtelierPrompt.coreInstructions.contains("EnterPlanMode"))
    }

    @Test("Core instructions mention ExitPlanMode")
    func mentionsExitPlanMode() {
        #expect(AtelierPrompt.coreInstructions.contains("ExitPlanMode"))
    }

    @Test("Core instructions require waiting for user approval")
    func requiresApproval() {
        #expect(AtelierPrompt.coreInstructions.contains("wait"))
        #expect(AtelierPrompt.coreInstructions.contains("approve"))
    }

    @Test("Core instructions steer toward non-technical language")
    func steersNonTechnical() {
        #expect(AtelierPrompt.coreInstructions.contains("non-technical"))
    }

    @Test("Core instructions reference project context files")
    func referencesContextFiles() {
        #expect(AtelierPrompt.coreInstructions.contains("context file"))
    }
}
