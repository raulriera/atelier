import Foundation
import Testing
@testable import AtelierKit

@Suite("DistillationEngine")
struct DistillationEngineTests {

    // Use a non-existent path so no real process is spawned.
    private func makeEngine() -> DistillationEngine {
        DistillationEngine(cliPath: "/nonexistent/claude")
    }

    // MARK: - Prompt Construction

    @Test func promptIncludesConversationSummary() async {
        let engine = makeEngine()
        let prompt = await engine.buildDistillationPrompt(
            conversationSummary: "User: Please use tabs",
            existingLearnings: nil
        )
        #expect(prompt.contains("User: Please use tabs"))
        #expect(prompt.contains("CONVERSATION"))
    }

    @Test func promptIncludesExistingLearnings() async {
        let engine = makeEngine()
        let prompt = await engine.buildDistillationPrompt(
            conversationSummary: "User: Hello",
            existingLearnings: "## Preferences\n- Use tabs"
        )
        #expect(prompt.contains("EXISTING LEARNINGS"))
        #expect(prompt.contains("Use tabs"))
    }

    @Test func promptOmitsExistingLearningsSectionWhenNil() async {
        let engine = makeEngine()
        let prompt = await engine.buildDistillationPrompt(
            conversationSummary: "User: Hello",
            existingLearnings: nil
        )
        #expect(!prompt.contains("EXISTING LEARNINGS"))
    }

    @Test func promptInstructsNoLearningsSentinel() async {
        let engine = makeEngine()
        let prompt = await engine.buildDistillationPrompt(
            conversationSummary: "User: Hello",
            existingLearnings: nil
        )
        #expect(prompt.contains("NO_LEARNINGS"))
    }

    @Test func promptInstructsMerging() async {
        let engine = makeEngine()
        let prompt = await engine.buildDistillationPrompt(
            conversationSummary: "User: Hello",
            existingLearnings: "existing"
        )
        #expect(prompt.contains("merge"))
    }

    // MARK: - Markdown Extraction

    @Test func extractMarkdownPassesThroughPlainContent() async {
        let engine = makeEngine()
        let result = await engine.extractMarkdownContent(from: "## Preferences\n- Use tabs")
        #expect(result == "## Preferences\n- Use tabs")
    }

    @Test func extractMarkdownStripsCodeFences() async {
        let engine = makeEngine()
        let result = await engine.extractMarkdownContent(
            from: "```markdown\n## Preferences\n- Use tabs\n```"
        )
        #expect(result == "## Preferences\n- Use tabs")
    }

    @Test func extractMarkdownStripsBareFences() async {
        let engine = makeEngine()
        let result = await engine.extractMarkdownContent(
            from: "```\n## Decisions\n- Chose X\n```"
        )
        #expect(result == "## Decisions\n- Chose X")
    }

    @Test func extractMarkdownTrimsWhitespace() async {
        let engine = makeEngine()
        let result = await engine.extractMarkdownContent(from: "  \n## Patterns\n  \n")
        #expect(result == "## Patterns")
    }

    // MARK: - NO_LEARNINGS Sentinel

    @Test func noLearningsSentinelValue() {
        #expect(DistillationEngine.noLearningsSentinel == "NO_LEARNINGS")
    }
}
