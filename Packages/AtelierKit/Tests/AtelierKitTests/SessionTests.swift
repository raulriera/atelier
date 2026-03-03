import Testing
import Foundation
@testable import AtelierKit

@Suite("Session")
struct SessionTests {

    @Suite("Messages")
    struct Messages {
        @Test("Appending a user message adds it to items")
        @MainActor func appendUserMessage() throws {
            let session = Session()
            session.appendUserMessage("Hello")
            #expect(session.items.count == 1)
            let msg = try #require(session.items[0].content.userMessage)
            #expect(msg.text == "Hello")
        }

        @Test("Begin and stream assistant text")
        @MainActor func beginAndStreamAssistant() {
            let session = Session()
            session.beginAssistantMessage()
            #expect(session.isStreaming)
            #expect(session.activeAssistantText == "")

            session.applyDelta("Hello")
            session.applyDelta(" world")
            #expect(session.activeAssistantText == "Hello world")
        }

        @Test("Completing assistant message finalizes it")
        @MainActor func completeAssistantMessage() throws {
            let session = Session()
            session.beginAssistantMessage()
            session.applyDelta("Done")
            session.completeAssistantMessage(usage: TokenUsage(inputTokens: 10, outputTokens: 5))

            #expect(!session.isStreaming)
            #expect(session.activeAssistantText == "")
            #expect(session.items.count == 1)

            let msg = try #require(session.items[0].content.assistantMessage)
            #expect(msg.text == "Done")
            #expect(msg.isComplete)
            #expect(msg.usage.inputTokens == 10)
            #expect(msg.usage.outputTokens == 5)
        }

        @Test("Multi-turn conversation tracks all items")
        @MainActor func multiTurnConversation() {
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

        @Test("Text after tool use creates new assistant message")
        @MainActor func textAfterToolUseCreatesNewAssistantMessage() throws {
            let session = Session()
            session.beginAssistantMessage()
            session.applyDelta("First thought")
            session.beginToolUse(id: "toolu_1", name: "Read")
            session.completeToolUse(id: "toolu_1")

            session.applyDelta("After the tool")

            // Items: assistant("First thought"), toolUse, assistant("After the tool" streaming)
            #expect(session.items.count == 3)
            let msg = try #require(session.items[0].content.assistantMessage)
            #expect(msg.text == "First thought")
            #expect(msg.isComplete)
            #expect(session.activeAssistantText == "After the tool")
        }
    }

    @Suite("Error handling")
    struct ErrorHandling {
        @Test("Error appends system event and saves partial text")
        @MainActor func handleErrorAppendsSystemEvent() throws {
            let session = Session()
            session.beginAssistantMessage()
            session.applyDelta("partial")
            session.handleError(.cliError("Rate limited"))

            #expect(!session.isStreaming)
            #expect(session.activeAssistantText == "")
            #expect(session.items.count == 2)

            let msg = try #require(session.items[0].content.assistantMessage)
            #expect(msg.text == "partial")
            #expect(msg.isComplete)

            let evt = try #require(session.items[1].content.system)
            #expect(evt.kind == .error)
            #expect(evt.message == "Rate limited")
        }

        @Test("Error removes empty assistant message")
        @MainActor func handleErrorRemovesEmptyAssistant() throws {
            let session = Session()
            session.beginAssistantMessage()
            session.handleError(.cliError("Failed"))

            #expect(!session.isStreaming)
            #expect(session.items.count == 1)

            let evt = try #require(session.items[0].content.system)
            #expect(evt.kind == .error)
        }
    }

    @Suite("Reset")
    struct Reset {
        @Test("Reset clears all state")
        @MainActor func resetClearsAllState() {
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

        @Test("Reset clears tool state")
        @MainActor func resetClearsToolState() {
            let session = Session()
            session.beginAssistantMessage()
            session.beginToolUse(id: "toolu_1", name: "Read")

            session.reset()

            #expect(session.items.isEmpty)
        }
    }

    @Suite("Thinking")
    struct Thinking {
        @Test("Thinking state transitions correctly")
        @MainActor func thinkingStateTransitions() {
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

        @Test("Thinking cleared on complete")
        @MainActor func thinkingClearedOnComplete() {
            let session = Session()
            session.beginAssistantMessage()
            session.beginThinking()
            session.applyThinkingDelta("thinking...")
            session.applyDelta("answer")
            session.completeAssistantMessage(usage: TokenUsage(inputTokens: 10, outputTokens: 5))

            #expect(!session.isThinking)
            #expect(session.thinkingText == "")
        }

        @Test("Thinking cleared on error")
        @MainActor func thinkingClearedOnError() {
            let session = Session()
            session.beginAssistantMessage()
            session.beginThinking()
            session.applyThinkingDelta("thinking...")
            session.handleError(.cliError("Error"))

            #expect(!session.isThinking)
            #expect(session.thinkingText == "")
        }
    }

    @Suite("Tool use")
    struct ToolUse {
        @Test("Begin tool use adds timeline item")
        @MainActor func beginToolUseAddsTimelineItem() throws {
            let session = Session()
            session.beginAssistantMessage()
            session.beginToolUse(id: "toolu_1", name: "Read")

            #expect(session.items.count == 1)
            let event = try #require(session.items[0].content.toolUse)
            #expect(event.id == "toolu_1")
            #expect(event.name == "Read")
            #expect(event.status == .running)
        }

        @Test("Tool input delta accumulates JSON")
        @MainActor func applyToolInputDeltaAccumulatesJSON() throws {
            let session = Session()
            session.beginAssistantMessage()
            session.beginToolUse(id: "toolu_1", name: "Read")
            session.applyToolInputDelta(id: "toolu_1", json: "{\"file_")
            session.applyToolInputDelta(id: "toolu_1", json: "path\":\"src/main.swift\"}")

            let event = try #require(session.items[0].content.toolUse)
            #expect(event.inputJSON == "{\"file_path\":\"src/main.swift\"}")
        }

        @Test("Complete tool use marks completed")
        @MainActor func completeToolUseMarksCompleted() throws {
            let session = Session()
            session.beginAssistantMessage()
            session.beginToolUse(id: "toolu_1", name: "Bash")
            session.completeToolUse(id: "toolu_1")

            let event = try #require(session.items[0].content.toolUse)
            #expect(event.status == .completed)
        }

        @Test("Multiple tools tracked independently")
        @MainActor func multipleToolsTrackedIndependently() throws {
            let session = Session()
            session.beginAssistantMessage()
            session.beginToolUse(id: "toolu_1", name: "Read")
            session.beginToolUse(id: "toolu_2", name: "Glob")

            session.completeToolUse(id: "toolu_1")

            let event1 = try #require(session.items[0].content.toolUse)
            #expect(event1.status == .completed)
            let event2 = try #require(session.items[1].content.toolUse)
            #expect(event2.status == .running)
        }

        @Test("Apply tool result sets resultOutput on correct tool")
        @MainActor func applyToolResultSetsResultOutput() throws {
            let session = Session()
            session.beginAssistantMessage()
            session.beginToolUse(id: "toolu_1", name: "Read")
            session.completeToolUse(id: "toolu_1")

            session.applyToolResult(id: "toolu_1", output: "file contents here")

            let event = try #require(session.items[0].content.toolUse)
            #expect(event.resultOutput == "file contents here")
        }

        @Test("Apply tool result accumulates output")
        @MainActor func applyToolResultAccumulatesOutput() throws {
            let session = Session()
            session.beginAssistantMessage()
            session.beginToolUse(id: "toolu_1", name: "Bash")
            session.completeToolUse(id: "toolu_1")

            session.applyToolResult(id: "toolu_1", output: "part1")
            session.applyToolResult(id: "toolu_1", output: "part2")

            let event = try #require(session.items[0].content.toolUse)
            #expect(event.resultOutput == "part1part2")
        }

        @Test("Apply tool result ignores unknown tool ID")
        @MainActor func applyToolResultIgnoresUnknownId() {
            let session = Session()
            session.beginAssistantMessage()
            session.beginToolUse(id: "toolu_1", name: "Read")
            session.completeToolUse(id: "toolu_1")

            session.applyToolResult(id: "toolu_unknown", output: "data")

            // Should not crash, item count unchanged
            #expect(session.items.count == 1)
        }

        @Test("Complete assistant message cleans up active tools")
        @MainActor func completeAssistantMessageCleansUpActiveTools() throws {
            let session = Session()
            session.beginAssistantMessage()
            session.beginToolUse(id: "toolu_1", name: "Read")

            session.completeAssistantMessage(usage: TokenUsage(inputTokens: 10, outputTokens: 5))

            let event = try #require(session.items[0].content.toolUse)
            #expect(event.status == .completed)
        }
    }

    @Suite("Persistence integrity")
    struct PersistenceIntegrity {
        @Test("Save excludes empty incomplete assistant messages")
        @MainActor func saveExcludesEmptyIncompleteAssistantMessages() async throws {
            let session = Session()
            session.sessionId = "test"
            session.appendUserMessage("Hello")
            session.beginAssistantMessage()

            let persistence = InMemorySessionPersistence()
            try await session.save(to: persistence)

            let snapshot = try #require(await persistence.load(id: "test"))
            #expect(snapshot.items.count == 1)
            let msg = try #require(snapshot.items[0].content.userMessage)
            #expect(msg.text == "Hello")
        }

        @Test("Save excludes error events")
        @MainActor func saveExcludesErrorEvents() async throws {
            let session = Session()
            session.sessionId = "test"
            session.appendUserMessage("Hello")
            session.appendSystemEvent(SystemEvent(kind: .error, message: "Something failed"))

            let persistence = InMemorySessionPersistence()
            try await session.save(to: persistence)

            let snapshot = try #require(await persistence.load(id: "test"))
            #expect(snapshot.items.count == 1)
        }

        @Test("Save preserves completed assistant messages")
        @MainActor func savePreservesCompletedAssistantMessages() async throws {
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

        @Test("Save preserves tool use items")
        @MainActor func savePreservesToolUseItems() async throws {
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
            #expect(snapshot.items.count == 2)
        }
    }

    @Suite("Restore")
    struct Restore {
        @Test("Restore filters orphaned assistant messages")
        @MainActor func restoreFiltersOrphanedAssistantMessages() throws {
            let brokenItems = [
                TimelineItem(content: .userMessage(UserMessage(text: "Hi"))),
                TimelineItem(content: .assistantMessage(AssistantMessage())),
                TimelineItem(content: .userMessage(UserMessage(text: "Hello?"))),
            ]
            let snapshot = SessionSnapshot(sessionId: "test", items: brokenItems)
            let session = Session.restore(from: snapshot)

            #expect(session.items.count == 2)
            for item in session.items {
                #expect(item.content.userMessage != nil, "Expected only userMessage items, got \(item.content)")
            }
        }

        @Test("Restore marks running tools as completed")
        @MainActor func restoreMarksRunningToolsAsCompleted() throws {
            let items = [
                TimelineItem(content: .toolUse(ToolUseEvent(id: "t1", name: "Bash", status: .running))),
                TimelineItem(content: .toolUse(ToolUseEvent(id: "t2", name: "Read", status: .completed))),
            ]
            let snapshot = SessionSnapshot(sessionId: "test", items: items)
            let session = Session.restore(from: snapshot)

            #expect(session.items.count == 2)
            for item in session.items {
                let event = try #require(item.content.toolUse)
                #expect(event.status == .completed, "Tool \(event.id) should be completed after restore")
            }
        }
    }

    @Suite("Interruption flag")
    struct InterruptionFlag {
        @Test("Save with interrupted flag preserves it")
        @MainActor func saveWithInterruptedFlagPreservesIt() async throws {
            let session = Session()
            session.sessionId = "test"
            session.appendUserMessage("Hello")

            let persistence = InMemorySessionPersistence()
            try await session.save(to: persistence, wasInterrupted: true)

            let snapshot = try #require(await persistence.load(id: "test"))
            #expect(snapshot.wasInterrupted)
        }

        @Test("Save defaults to not interrupted")
        @MainActor func saveDefaultsToNotInterrupted() async throws {
            let session = Session()
            session.sessionId = "test"
            session.appendUserMessage("Hello")

            let persistence = InMemorySessionPersistence()
            try await session.save(to: persistence)

            let snapshot = try #require(await persistence.load(id: "test"))
            #expect(!snapshot.wasInterrupted)
        }

        @Test("Restore from interrupted snapshot cleans up normally")
        @MainActor func restoreFromInterruptedSnapshotCleansUpNormally() throws {
            let items = [
                TimelineItem(content: .userMessage(UserMessage(text: "Hi"))),
                TimelineItem(content: .toolUse(ToolUseEvent(id: "t1", name: "Read", status: .running))),
                TimelineItem(content: .assistantMessage(AssistantMessage())),
            ]
            let snapshot = SessionSnapshot(sessionId: "test", items: items, wasInterrupted: true)
            let session = Session.restore(from: snapshot)

            #expect(session.items.count == 2)
            let event = try #require(session.items[1].content.toolUse)
            #expect(event.status == .completed)
        }
    }

    @Suite("Pending message queue")
    struct PendingMessageQueue {
        @Test("Enqueue adds message to queue and timeline")
        @MainActor func enqueueAddsToQueueAndTimeline() throws {
            let session = Session()
            session.enqueuePendingMessage("Next thought")

            #expect(session.pendingMessages == ["Next thought"])
            #expect(session.items.count == 1)
            let msg = try #require(session.items[0].content.userMessage)
            #expect(msg.text == "Next thought")
        }

        @Test("Dequeue returns messages in FIFO order")
        @MainActor func dequeueReturnsFIFO() {
            let session = Session()
            session.enqueuePendingMessage("First")
            session.enqueuePendingMessage("Second")

            #expect(session.dequeuePendingMessage() == "First")
            #expect(session.dequeuePendingMessage() == "Second")
            #expect(session.dequeuePendingMessage() == nil)
        }

        @Test("Dequeue returns nil when empty")
        @MainActor func dequeueReturnsNilWhenEmpty() {
            let session = Session()
            #expect(session.dequeuePendingMessage() == nil)
        }

        @Test("Reset clears pending messages")
        @MainActor func resetClearsPendingMessages() {
            let session = Session()
            session.enqueuePendingMessage("Queued")

            session.reset()

            #expect(session.pendingMessages.isEmpty)
        }

        @Test("Pending messages persist in snapshot")
        @MainActor func pendingMessagesPersistInSnapshot() async throws {
            let session = Session()
            session.sessionId = "test"
            session.enqueuePendingMessage("Waiting")

            let persistence = InMemorySessionPersistence()
            try await session.save(to: persistence)

            let snapshot = try #require(await persistence.load(id: "test"))
            #expect(snapshot.pendingMessages == ["Waiting"])
        }

        @Test("Clear marks pending items as cancelled")
        @MainActor func clearMarksPendingAsCancelled() {
            let session = Session()
            session.enqueuePendingMessage("First")
            session.enqueuePendingMessage("Second")

            let itemIDs = session.items.map(\.id)
            session.clearPendingMessages()

            #expect(session.pendingMessages.isEmpty)
            #expect(session.dequeuePendingMessage() == nil)
            // User bubbles stay in the timeline
            #expect(session.items.count == 2)
            // Their IDs are in the cancelled set
            for id in itemIDs {
                #expect(session.cancelledItemIDs.contains(id))
            }
        }

        @Test("Error clears pending messages and marks them cancelled but not the active message")
        @MainActor func errorClearsPendingMessages() {
            let session = Session()
            session.appendUserMessage("Ask something")
            let activeID = session.items[0].id
            session.beginAssistantMessage()
            session.enqueuePendingMessage("Queued")
            let queuedID = session.items.last!.id

            session.handleError(.cliError("Failed"))

            #expect(session.pendingMessages.isEmpty)
            // Queued message is cancelled
            #expect(session.cancelledItemIDs.contains(queuedID))
            // Active message is NOT cancelled — the error event handles that UX
            #expect(!session.cancelledItemIDs.contains(activeID))
        }

        @Test("Pending messages are not restored from snapshot")
        @MainActor func pendingMessagesNotRestoredFromSnapshot() {
            let snapshot = SessionSnapshot(
                sessionId: "test",
                items: [TimelineItem(content: .userMessage(UserMessage(text: "Queued")))],
                pendingMessages: ["Queued"]
            )
            let session = Session.restore(from: snapshot)

            // Pending messages are transient — restoring them without
            // pendingItemIDs would crash dequeuePendingMessage().
            #expect(session.pendingMessages.isEmpty)
        }
    }

    @Suite("Queue orchestration")
    struct QueueOrchestration {
        @Test("Normal conversation: send, stream, complete")
        @MainActor func normalConversation() throws {
            let session = Session()

            // User sends a message
            session.appendUserMessage("Hello")
            session.beginAssistantMessage()
            #expect(session.isStreaming)

            // Claude responds
            session.applyDelta("Hi there!")
            session.completeAssistantMessage(usage: TokenUsage(inputTokens: 5, outputTokens: 3))

            #expect(!session.isStreaming)
            #expect(session.pendingMessages.isEmpty)
            #expect(session.items.count == 2)

            let user = try #require(session.items[0].content.userMessage)
            #expect(user.text == "Hello")
            let assistant = try #require(session.items[1].content.assistantMessage)
            #expect(assistant.text == "Hi there!")
            #expect(assistant.isComplete)
        }

        @Test("Queued messages: all dispatched in sequence")
        @MainActor func queuedMessagesAllDispatched() throws {
            let session = Session()

            // First message begins streaming
            session.appendUserMessage("First")
            session.beginAssistantMessage()
            session.applyDelta("Response to first")

            // While streaming, user queues two more messages
            session.enqueuePendingMessage("Second")
            session.enqueuePendingMessage("Third")

            #expect(session.pendingMessages.count == 2)
            // Timeline: user("First"), assistant(streaming), user("Second"), user("Third")
            #expect(session.items.count == 4)

            // First response completes — dequeue "Second"
            session.completeAssistantMessage(usage: TokenUsage(inputTokens: 10, outputTokens: 5))
            let queued1 = session.dequeuePendingMessage()
            #expect(queued1 == "Second")
            #expect(session.pendingMessages == ["Third"])

            // Begin response to "Second"
            session.beginAssistantMessage()
            session.applyDelta("Got it")
            session.completeAssistantMessage(usage: TokenUsage(inputTokens: 8, outputTokens: 3))

            // Dequeue "Third"
            let queued2 = session.dequeuePendingMessage()
            #expect(queued2 == "Third")
            #expect(session.pendingMessages.isEmpty)

            // Begin response to "Third"
            session.beginAssistantMessage()
            session.applyDelta("Done")
            session.completeAssistantMessage(usage: TokenUsage(inputTokens: 6, outputTokens: 2))

            // No more queued messages
            #expect(session.dequeuePendingMessage() == nil)
            #expect(!session.isStreaming)
            // Timeline: user, assistant, user, user, assistant, assistant
            #expect(session.items.count == 6)
        }

        @Test("Stop with no queue cancels the active user message")
        @MainActor func stopWithNoQueueCancelsActiveMessage() throws {
            let session = Session()

            // User sends a message, streaming begins
            session.appendUserMessage("Hello")
            let userItemID = session.items[0].id
            session.beginAssistantMessage()
            session.applyDelta("Starting to respond...")

            // User hits stop — simulating stopGeneration()
            session.clearPendingMessages()
            session.completeAssistantMessage(usage: TokenUsage())

            #expect(!session.isStreaming)
            #expect(session.cancelledItemIDs.contains(userItemID))
        }

        @Test("Stop generation clears queue and marks all bubbles cancelled")
        @MainActor func stopGenerationClearsQueue() throws {
            let session = Session()

            // User sends first message, streaming begins
            session.appendUserMessage("Hello")
            let activeID = session.items[0].id
            session.beginAssistantMessage()
            session.applyDelta("Starting to respond...")

            // User queues a follow-up while streaming
            session.enqueuePendingMessage("Follow up")
            #expect(session.pendingMessages == ["Follow up"])

            // User hits stop — simulating stopGeneration()
            session.clearPendingMessages()
            session.completeAssistantMessage(usage: TokenUsage())

            // Queue is cleared, no messages dispatched
            #expect(session.pendingMessages.isEmpty)
            #expect(session.dequeuePendingMessage() == nil)
            #expect(!session.isStreaming)

            // Timeline: user("Hello"), assistant, user("Follow up" cancelled)
            #expect(session.items.count == 3)
            let assistant = try #require(session.items[1].content.assistantMessage)
            #expect(assistant.text == "Starting to respond...")
            // Both the active and queued messages are cancelled
            #expect(session.cancelledItemIDs.contains(activeID))
            #expect(session.cancelledItemIDs.contains(session.items[2].id))
        }

        @Test("Stop after dispatched queued message marks it cancelled")
        @MainActor func stopAfterDispatchedQueuedMessage() throws {
            let session = Session()

            // First message streaming
            session.appendUserMessage("Hello")
            session.beginAssistantMessage()
            session.applyDelta("Hi!")

            // User queues a follow-up
            session.enqueuePendingMessage("Follow up")

            // First response completes, queued message auto-dispatched
            session.completeAssistantMessage(usage: TokenUsage(inputTokens: 5, outputTokens: 3))
            let queued = session.dequeuePendingMessage()
            #expect(queued == "Follow up")

            // New stream starts for the dispatched message
            session.beginAssistantMessage()
            session.applyDelta("Starting follow-up response...")

            // User hits stop — simulating stopGeneration()
            session.clearPendingMessages()
            session.completeAssistantMessage(usage: TokenUsage())

            // The dispatched message's bubble should be cancelled
            #expect(session.cancelledItemIDs.contains(session.items[2].id))
        }

        @Test("Error during streaming clears queued messages")
        @MainActor func errorDuringStreamingClearsQueue() {
            let session = Session()

            session.appendUserMessage("Try this")
            session.beginAssistantMessage()
            session.enqueuePendingMessage("And this")

            #expect(session.pendingMessages == ["And this"])

            // CLI errors out
            session.handleError(.cliError("Rate limited"))

            #expect(session.pendingMessages.isEmpty)
            #expect(!session.isStreaming)
            // Queued messages are not dispatched
            #expect(session.dequeuePendingMessage() == nil)
        }
    }
}
