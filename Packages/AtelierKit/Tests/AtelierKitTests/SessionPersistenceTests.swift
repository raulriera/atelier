import Testing
import Foundation
@testable import AtelierKit

@Test @MainActor func saveCreatesSnapshotWithCorrectItems() async throws {
    let persistence = InMemorySessionPersistence()
    let session = Session()
    session.sessionId = "test-123"
    session.appendUserMessage("Hello")
    session.beginAssistantMessage()
    session.applyDelta("Hi there")
    session.completeAssistantMessage(usage: TokenUsage(inputTokens: 5, outputTokens: 3))

    try await session.save(to: persistence)

    let snapshot = await persistence.load(id: "test-123")
    #expect(snapshot != nil)
    #expect(snapshot?.sessionId == "test-123")
    #expect(snapshot?.items.count == 2)
}

@Test @MainActor func loadRestoresItemsAndSessionId() async throws {
    let persistence = InMemorySessionPersistence()

    let items = [
        TimelineItem(content: .userMessage(UserMessage(text: "Hello"))),
        TimelineItem(content: .assistantMessage(AssistantMessage(text: "Hi", isComplete: true, usage: TokenUsage(inputTokens: 3, outputTokens: 2)))),
    ]
    let snapshot = SessionSnapshot(sessionId: "restore-456", items: items)
    await persistence.save(snapshot)

    let loaded = await persistence.load(id: "restore-456")
    #expect(loaded != nil)

    let session = Session.restore(from: loaded!)

    #expect(session.sessionId == "restore-456")
    #expect(session.items.count == 2)

    if case .userMessage(let msg) = session.items[0].content {
        #expect(msg.text == "Hello")
    } else {
        Issue.record("Expected userMessage")
    }
}

@Test func loadMostRecentReturnsLatestSession() async throws {
    let persistence = InMemorySessionPersistence()

    let older = SessionSnapshot(
        sessionId: "old",
        items: [TimelineItem(content: .userMessage(UserMessage(text: "Old")))],
        savedAt: Date(timeIntervalSince1970: 1_000_000)
    )
    let newer = SessionSnapshot(
        sessionId: "new",
        items: [TimelineItem(content: .userMessage(UserMessage(text: "New")))],
        savedAt: Date(timeIntervalSince1970: 2_000_000)
    )

    await persistence.save(older)
    await persistence.save(newer)

    let mostRecent = await persistence.loadMostRecent()
    #expect(mostRecent?.sessionId == "new")
}

@Test @MainActor func roundTripPreservesContent() async throws {
    let persistence = InMemorySessionPersistence()

    let session = Session()
    session.sessionId = "round-trip"
    session.appendUserMessage("Question?")
    session.beginAssistantMessage()
    session.applyDelta("Answer.")
    session.completeAssistantMessage(usage: TokenUsage(inputTokens: 10, outputTokens: 8))
    session.appendSystemEvent(SystemEvent(kind: .sessionStarted, message: "Session started"))

    try await session.save(to: persistence)

    let snapshot = await persistence.load(id: "round-trip")
    let restored = Session.restore(from: snapshot!)

    #expect(restored.items.count == 3)

    if case .assistantMessage(let msg) = restored.items[1].content {
        #expect(msg.text == "Answer.")
        #expect(msg.isComplete)
        #expect(msg.usage.inputTokens == 10)
    } else {
        Issue.record("Expected assistantMessage")
    }
}

@Test @MainActor func saveFiltersTransientErrorEvents() async throws {
    let persistence = InMemorySessionPersistence()

    let session = Session()
    session.sessionId = "filter-test"
    session.appendUserMessage("Hello")
    session.appendSystemEvent(SystemEvent(kind: .error, message: "Connection lost"))
    session.appendSystemEvent(SystemEvent(kind: .sessionStarted, message: "Session started"))

    try await session.save(to: persistence)

    let snapshot = await persistence.load(id: "filter-test")
    #expect(snapshot?.items.count == 2) // user message + sessionStarted, error filtered out

    for item in snapshot!.items {
        if case .system(let event) = item.content {
            #expect(event.kind != .error)
        }
    }
}

@Test func deleteRemovesSession() async throws {
    let persistence = InMemorySessionPersistence()

    let snapshot = SessionSnapshot(
        sessionId: "delete-me",
        items: [TimelineItem(content: .userMessage(UserMessage(text: "Bye")))]
    )
    await persistence.save(snapshot)
    #expect(await persistence.load(id: "delete-me") != nil)

    await persistence.delete(id: "delete-me")
    #expect(await persistence.load(id: "delete-me") == nil)
}
