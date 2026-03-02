import Testing
import Foundation
@testable import AtelierKit

@Test @MainActor func appendUserMessage() {
    let session = Session()
    session.appendUserMessage("Hello")
    #expect(session.items.count == 1)
    if case .userMessage(let msg) = session.items[0].content {
        #expect(msg.text == "Hello")
    } else {
        Issue.record("Expected userMessage")
    }
}

@Test @MainActor func beginAndStreamAssistant() {
    let session = Session()
    session.beginAssistantMessage()
    #expect(session.isStreaming)
    #expect(session.activeAssistantText == "")

    session.applyDelta("Hello")
    session.applyDelta(" world")
    #expect(session.activeAssistantText == "Hello world")
}

@Test @MainActor func completeAssistantMessage() {
    let session = Session()
    session.beginAssistantMessage()
    session.applyDelta("Done")
    session.completeAssistantMessage(usage: TokenUsage(inputTokens: 10, outputTokens: 5))

    #expect(!session.isStreaming)
    #expect(session.activeAssistantText == "")
    #expect(session.items.count == 1)

    if case .assistantMessage(let msg) = session.items[0].content {
        #expect(msg.text == "Done")
        #expect(msg.isComplete)
        #expect(msg.usage.inputTokens == 10)
        #expect(msg.usage.outputTokens == 5)
    } else {
        Issue.record("Expected assistantMessage")
    }
}

@Test @MainActor func handleErrorAppendsSystemEvent() {
    let session = Session()
    session.beginAssistantMessage()
    session.applyDelta("partial")
    session.handleError(.cliError("Rate limited"))

    #expect(!session.isStreaming)
    #expect(session.activeAssistantText == "")
    // assistant item (partial text saved) + error system event
    #expect(session.items.count == 2)
    if case .assistantMessage(let msg) = session.items[0].content {
        #expect(msg.text == "partial")
        #expect(msg.isComplete)
    } else {
        Issue.record("Expected assistantMessage with partial text")
    }
    if case .system(let evt) = session.items[1].content {
        #expect(evt.kind == .error)
        #expect(evt.message == "Rate limited")
    } else {
        Issue.record("Expected system error event")
    }
}

@Test @MainActor func handleErrorRemovesEmptyAssistant() {
    let session = Session()
    session.beginAssistantMessage()
    session.handleError(.cliError("Failed"))

    #expect(!session.isStreaming)
    // Empty assistant removed, only error event remains
    #expect(session.items.count == 1)
    if case .system(let evt) = session.items[0].content {
        #expect(evt.kind == .error)
    } else {
        Issue.record("Expected system error event")
    }
}

@Test @MainActor func multiTurnConversation() {
    let session = Session()

    session.appendUserMessage("Hi")
    session.beginAssistantMessage()
    session.applyDelta("Hey!")
    session.completeAssistantMessage(usage: TokenUsage(inputTokens: 5, outputTokens: 3))

    session.appendUserMessage("How are you?")
    session.beginAssistantMessage()
    session.applyDelta("Great!")
    session.completeAssistantMessage(usage: TokenUsage(inputTokens: 12, outputTokens: 4))

    #expect(session.items.count == 4)
    #expect(!session.isStreaming)
}

@Test @MainActor func resetClearsAllState() {
    let session = Session()
    session.sessionId = "test-session"
    session.appendUserMessage("Hello")
    session.beginAssistantMessage()
    session.applyDelta("Hi!")
    session.completeAssistantMessage(usage: TokenUsage(inputTokens: 5, outputTokens: 3))

    session.reset()

    #expect(session.items.isEmpty)
    #expect(session.activeAssistantText == "")
    #expect(!session.isStreaming)
    #expect(!session.isThinking)
    #expect(session.thinkingText == "")
    #expect(session.sessionId == nil)
}

@Test @MainActor func thinkingStateTransitions() {
    let session = Session()
    session.beginAssistantMessage()

    session.beginThinking()
    #expect(session.isThinking)
    #expect(session.thinkingText == "")

    session.applyThinkingDelta("Let me think...")
    #expect(session.thinkingText == "Let me think...")

    // applyDelta clears thinking state
    session.applyDelta("Here's my answer")
    #expect(!session.isThinking)
    #expect(session.activeAssistantText == "Here's my answer")
}

@Test @MainActor func thinkingClearedOnComplete() {
    let session = Session()
    session.beginAssistantMessage()
    session.beginThinking()
    session.applyThinkingDelta("thinking...")
    session.applyDelta("answer")
    session.completeAssistantMessage(usage: TokenUsage(inputTokens: 10, outputTokens: 5))

    #expect(!session.isThinking)
    #expect(session.thinkingText == "")
}

@Test @MainActor func thinkingClearedOnError() {
    let session = Session()
    session.beginAssistantMessage()
    session.beginThinking()
    session.applyThinkingDelta("thinking...")
    session.handleError(.cliError("Error"))

    #expect(!session.isThinking)
    #expect(session.thinkingText == "")
}

// MARK: - Tool Use

@Test @MainActor func beginToolUseAddsTimelineItem() {
    let session = Session()
    session.beginAssistantMessage()
    session.beginToolUse(id: "toolu_1", name: "Read")

    // Empty assistant removed, only tool use remains
    #expect(session.items.count == 1)
    if case .toolUse(let event) = session.items[0].content {
        #expect(event.id == "toolu_1")
        #expect(event.name == "Read")
        #expect(event.status == .running)
    } else {
        Issue.record("Expected toolUse")
    }
}

@Test @MainActor func applyToolInputDeltaAccumulatesJSON() {
    let session = Session()
    session.beginAssistantMessage()
    session.beginToolUse(id: "toolu_1", name: "Read")
    session.applyToolInputDelta(id: "toolu_1", json: "{\"file_")
    session.applyToolInputDelta(id: "toolu_1", json: "path\":\"src/main.swift\"}")

    if case .toolUse(let event) = session.items[0].content {
        #expect(event.inputJSON == "{\"file_path\":\"src/main.swift\"}")
    } else {
        Issue.record("Expected toolUse")
    }
}

@Test @MainActor func completeToolUseMarksCompleted() {
    let session = Session()
    session.beginAssistantMessage()
    session.beginToolUse(id: "toolu_1", name: "Bash")
    session.completeToolUse(id: "toolu_1")

    if case .toolUse(let event) = session.items[0].content {
        #expect(event.status == .completed)
    } else {
        Issue.record("Expected toolUse")
    }
}

@Test @MainActor func multipleToolsTrackedIndependently() {
    let session = Session()
    session.beginAssistantMessage()
    session.beginToolUse(id: "toolu_1", name: "Read")
    session.beginToolUse(id: "toolu_2", name: "Glob")

    session.completeToolUse(id: "toolu_1")

    if case .toolUse(let event1) = session.items[0].content {
        #expect(event1.status == .completed)
    } else {
        Issue.record("Expected toolUse for toolu_1")
    }
    if case .toolUse(let event2) = session.items[1].content {
        #expect(event2.status == .running)
    } else {
        Issue.record("Expected toolUse for toolu_2")
    }
}

@Test @MainActor func completeAssistantMessageCleansUpActiveTools() {
    let session = Session()
    session.beginAssistantMessage()
    session.beginToolUse(id: "toolu_1", name: "Read")

    session.completeAssistantMessage(usage: TokenUsage(inputTokens: 10, outputTokens: 5))

    if case .toolUse(let event) = session.items[0].content {
        #expect(event.status == .completed)
    } else {
        Issue.record("Expected toolUse")
    }
}

@Test @MainActor func resetClearsToolState() {
    let session = Session()
    session.beginAssistantMessage()
    session.beginToolUse(id: "toolu_1", name: "Read")

    session.reset()

    #expect(session.items.isEmpty)
}

@Test @MainActor func textAfterToolUseCreatesNewAssistantMessage() {
    let session = Session()
    session.beginAssistantMessage()
    session.applyDelta("First thought")
    session.beginToolUse(id: "toolu_1", name: "Read")
    session.completeToolUse(id: "toolu_1")

    // This should start a fresh assistant message
    session.applyDelta("After the tool")

    // Items: assistant("First thought"), toolUse, assistant("After the tool" streaming)
    #expect(session.items.count == 3)
    if case .assistantMessage(let msg) = session.items[0].content {
        #expect(msg.text == "First thought")
        #expect(msg.isComplete)
    } else {
        Issue.record("Expected first assistantMessage")
    }
    #expect(session.activeAssistantText == "After the tool")
}

// MARK: - Persistence Integrity

@Test @MainActor func saveExcludesEmptyIncompleteAssistantMessages() async throws {
    let session = Session()
    session.sessionId = "test"
    session.appendUserMessage("Hello")
    // Simulate an orphaned empty assistant message
    session.beginAssistantMessage()

    let persistence = InMemorySessionPersistence()
    try await session.save(to: persistence)

    let snapshot = try #require(await persistence.load(id: "test"))
    // Only the user message should be saved
    #expect(snapshot.items.count == 1)
    if case .userMessage(let msg) = snapshot.items[0].content {
        #expect(msg.text == "Hello")
    } else {
        Issue.record("Expected userMessage")
    }
}

@Test @MainActor func saveExcludesErrorEvents() async throws {
    let session = Session()
    session.sessionId = "test"
    session.appendUserMessage("Hello")
    session.appendSystemEvent(SystemEvent(kind: .error, message: "Something failed"))

    let persistence = InMemorySessionPersistence()
    try await session.save(to: persistence)

    let snapshot = try #require(await persistence.load(id: "test"))
    #expect(snapshot.items.count == 1)
}

@Test @MainActor func savePreservesCompletedAssistantMessages() async throws {
    let session = Session()
    session.sessionId = "test"
    session.appendUserMessage("Hi")
    session.beginAssistantMessage()
    session.applyDelta("Hello!")
    session.completeAssistantMessage(usage: TokenUsage(inputTokens: 5, outputTokens: 3))

    let persistence = InMemorySessionPersistence()
    try await session.save(to: persistence)

    let snapshot = try #require(await persistence.load(id: "test"))
    #expect(snapshot.items.count == 2)
}

@Test @MainActor func savePreservesToolUseItems() async throws {
    let session = Session()
    session.sessionId = "test"
    session.beginAssistantMessage()
    session.beginToolUse(id: "toolu_1", name: "Read")
    session.completeToolUse(id: "toolu_1")
    session.applyDelta("Done")
    session.completeAssistantMessage(usage: TokenUsage(inputTokens: 5, outputTokens: 3))

    let persistence = InMemorySessionPersistence()
    try await session.save(to: persistence)

    let snapshot = try #require(await persistence.load(id: "test"))
    // tool use + assistant message
    #expect(snapshot.items.count == 2)
}

@Test @MainActor func restoreFiltersOrphanedAssistantMessages() {
    let brokenItems = [
        TimelineItem(content: .userMessage(UserMessage(text: "Hi"))),
        TimelineItem(content: .assistantMessage(AssistantMessage())), // orphaned
        TimelineItem(content: .userMessage(UserMessage(text: "Hello?"))),
    ]
    let snapshot = SessionSnapshot(sessionId: "test", items: brokenItems)
    let session = Session.restore(from: snapshot)

    #expect(session.items.count == 2)
    // Both should be user messages
    for item in session.items {
        if case .userMessage = item.content { continue }
        Issue.record("Expected only userMessage items, got \(item.content)")
    }
}

@Test @MainActor func restoreMarksRunningToolsAsCompleted() {
    let items = [
        TimelineItem(content: .toolUse(ToolUseEvent(id: "t1", name: "Bash", status: .running))),
        TimelineItem(content: .toolUse(ToolUseEvent(id: "t2", name: "Read", status: .completed))),
    ]
    let snapshot = SessionSnapshot(sessionId: "test", items: items)
    let session = Session.restore(from: snapshot)

    #expect(session.items.count == 2)
    for item in session.items {
        if case .toolUse(let event) = item.content {
            #expect(event.status == .completed, "Tool \(event.id) should be completed after restore")
        }
    }
}
