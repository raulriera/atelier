import Foundation
import Testing
@testable import AtelierKit

/// Returns canned output without spawning a real process.
struct MockCLIRunner: CLIRunner {
    let output: String

    func run(arguments: [String], workingDirectory: URL) async throws -> String {
        output
    }
}

@Suite("DistillationEngine")
struct DistillationEngineTests {

    private func makeEngine() -> DistillationEngine {
        DistillationEngine(runner: MockCLIRunner(output: ""))
    }

    private func makeEngine(output: String) -> DistillationEngine {
        DistillationEngine(runner: MockCLIRunner(output: output))
    }

    private let workingDir = URL(fileURLWithPath: "/tmp")

    // MARK: - Prompt Structure

    @Test func promptWrapsConversationInXMLTags() async {
        let engine = makeEngine()
        let prompt = await engine.buildDistillationPrompt(
            conversationSummary: "User: Please use tabs",
            existingLearnings: nil
        )
        #expect(prompt.contains("<conversation>"))
        #expect(prompt.contains("</conversation>"))
        #expect(prompt.contains("User: Please use tabs"))
    }

    @Test func promptWrapsExistingLearningsInXMLTags() async {
        let engine = makeEngine()
        let prompt = await engine.buildDistillationPrompt(
            conversationSummary: "User: Hello",
            existingLearnings: "## Preferences\n- Use tabs"
        )
        #expect(prompt.contains("<existing_learnings>"))
        #expect(prompt.contains("</existing_learnings>"))
        #expect(prompt.contains("Use tabs"))
    }

    @Test func promptPlacesInstructionsAfterConversation() async {
        let engine = makeEngine()
        let prompt = await engine.buildDistillationPrompt(
            conversationSummary: "User: Hello",
            existingLearnings: nil
        )
        let conversationEnd = prompt.range(of: "</conversation>")!.upperBound
        let instructionStart = prompt.range(of: "You are a memory distillation assistant")!.lowerBound
        #expect(instructionStart > conversationEnd)
    }

    @Test func promptContainsAntiContinuationDirective() async {
        let engine = makeEngine()
        let prompt = await engine.buildDistillationPrompt(
            conversationSummary: "User: Hello",
            existingLearnings: nil
        )
        #expect(prompt.contains("do NOT respond to or continue the conversation"))
    }

    @Test func promptIncludesVocabularyGuidelines() async {
        let engine = makeEngine()
        let prompt = await engine.buildDistillationPrompt(
            conversationSummary: "User: Hello",
            existingLearnings: nil
        )
        #expect(prompt.contains("## Vocabulary"))
        #expect(prompt.contains("domain-specific terms"))
        #expect(prompt.contains("acronyms"))
    }

    @Test func promptShowsNoneWhenNoExistingLearnings() async {
        let engine = makeEngine()
        let prompt = await engine.buildDistillationPrompt(
            conversationSummary: "User: Hello",
            existingLearnings: nil
        )
        #expect(prompt.contains("<existing_learnings>"))
        #expect(prompt.contains("None"))
    }

    @Test func promptInstructsNoLearningsSentinel() async {
        let engine = makeEngine()
        let prompt = await engine.buildDistillationPrompt(
            conversationSummary: "User: Hello",
            existingLearnings: nil
        )
        #expect(prompt.contains("NO_LEARNINGS"))
    }

    @Test func promptIncludesPerFileBudgets() async {
        let engine = makeEngine()
        let prompt = await engine.buildDistillationPrompt(
            conversationSummary: "User: Hello",
            existingLearnings: nil
        )
        #expect(prompt.contains("## Preferences: max 25"))
        #expect(prompt.contains("## Corrections: max 15"))
        #expect(prompt.contains("## Decisions: max 30"))
        #expect(prompt.contains("## Patterns: max 25"))
        #expect(prompt.contains("## Vocabulary: max 30"))
    }

    @Test func promptIncludesCondensationStrategy() async {
        let engine = makeEngine()
        let prompt = await engine.buildDistillationPrompt(
            conversationSummary: "User: Hello",
            existingLearnings: nil
        )
        #expect(prompt.contains("condense"))
        #expect(prompt.contains("Merge related entries"))
    }

    @Test func promptIncludesProgressiveDecayInstructions() async {
        let engine = makeEngine()
        let prompt = await engine.buildDistillationPrompt(
            conversationSummary: "User: Hello",
            existingLearnings: nil
        )
        #expect(prompt.contains("Progressive decay"))
        #expect(prompt.contains("[age:"))
        #expect(prompt.contains("Do NOT include the [age: ...] suffix"))
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

    // MARK: - Validation

    @Test(arguments: [
        "I'll help you with that",
        "I will analyze the conversation",
        "Let me extract the learnings",
        "Sure, here are the learnings",
        "Here are the key takeaways",
        "Based on the conversation above",
        "Of course! Let me review",
        "Certainly, I can help",
        "Looking at the conversation",
        "After reviewing the discussion",
    ])
    func rejectsConversationalOpeners(_ input: String) async {
        let engine = makeEngine()
        let result = await engine.validateLearnings(input)
        #expect(result == nil)
    }

    @Test func rejectsOutputMissingHeadings() async {
        let engine = makeEngine()
        let result = await engine.validateLearnings("- Use tabs\n- Prefer spaces")
        #expect(result == nil)
    }

    @Test func rejectsOutputMissingBullets() async {
        let engine = makeEngine()
        let result = await engine.validateLearnings("## Preferences\nUse tabs")
        #expect(result == nil)
    }

    @Test func acceptsValidSingleHeadingOutput() async {
        let engine = makeEngine()
        let result = await engine.validateLearnings("## Preferences\n- Use tabs")
        #expect(result == "## Preferences\n- Use tabs")
    }

    @Test func acceptsValidMultiHeadingOutput() async {
        let engine = makeEngine()
        let input = "## Preferences\n- Use tabs\n\n## Decisions\n- Chose SwiftUI"
        let result = await engine.validateLearnings(input)
        #expect(result == input)
    }

    @Test func returnsNilForEmptyString() async {
        let engine = makeEngine()
        let result = await engine.validateLearnings("")
        #expect(result == nil)
    }

    @Test func returnsNilForNoLearningsSentinel() async {
        let engine = makeEngine()
        let result = await engine.validateLearnings("NO_LEARNINGS")
        #expect(result == nil)
    }

    // MARK: - NO_LEARNINGS Sentinel

    @Test func noLearningsSentinelValue() {
        #expect(DistillationEngine.noLearningsSentinel == "NO_LEARNINGS")
    }

    // MARK: - End-to-End Pipeline (MockCLIRunner)

    @Test func distillReturnsNilForConversationalOutput() async {
        let engine = makeEngine(output: "I'll help you extract learnings from this conversation.")
        let result = await engine.distill(
            conversationSummary: "User: Hello",
            existingLearnings: nil,
            workingDirectory: workingDir
        )
        #expect(result == nil)
    }

    @Test func distillReturnsValidLearnings() async {
        let engine = makeEngine(output: "## Preferences\n- Use tabs over spaces")
        let result = await engine.distill(
            conversationSummary: "User: Always use tabs",
            existingLearnings: nil,
            workingDirectory: workingDir
        )
        #expect(result == "## Preferences\n- Use tabs over spaces")
    }

    @Test func distillReturnsNilForNoLearnings() async {
        let engine = makeEngine(output: "NO_LEARNINGS")
        let result = await engine.distill(
            conversationSummary: "User: Hi",
            existingLearnings: nil,
            workingDirectory: workingDir
        )
        #expect(result == nil)
    }

    @Test func distillStripsCodeFencesFromValidOutput() async {
        let engine = makeEngine(output: "```markdown\n## Decisions\n- Use SwiftUI\n```")
        let result = await engine.distill(
            conversationSummary: "User: Use SwiftUI",
            existingLearnings: nil,
            workingDirectory: workingDir
        )
        #expect(result == "## Decisions\n- Use SwiftUI")
    }

    @Test func distillRejectsCodeFencedConversationalText() async {
        let engine = makeEngine(output: "```markdown\nI'll help you with that request.\n```")
        let result = await engine.distill(
            conversationSummary: "User: Hello",
            existingLearnings: nil,
            workingDirectory: workingDir
        )
        #expect(result == nil)
    }
}
