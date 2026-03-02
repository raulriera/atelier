import Testing
import Foundation
@testable import AtelierKit

@Suite("SessionPersistence")
struct SessionPersistenceTests {

    @Suite("Save and load")
    struct SaveAndLoad {
        @Test("Save creates snapshot with correct items")
        @MainActor func saveCreatesSnapshotWithCorrectItems() async throws {
            let persistence = InMemorySessionPersistence()
            let session = Session()
            session.sessionId = "test-123"
            session.appendUserMessage("Hello")
            session.beginAssistantMessage()
            session.applyDelta("Hi there")
            session.completeAssistantMessage(usage: TokenUsage(inputTokens: 5, outputTokens: 3))

            try await session.save(to: persistence)

            let snapshot = try #require(await persistence.load(id: "test-123"))
            #expect(snapshot.sessionId == "test-123")
            #expect(snapshot.items.count == 2)
        }

        @Test("Load restores items and session ID")
        @MainActor func loadRestoresItemsAndSessionId() async throws {
            let persistence = InMemorySessionPersistence()

            let items = [
                TimelineItem(content: .userMessage(UserMessage(text: "Hello"))),
                TimelineItem(content: .assistantMessage(AssistantMessage(text: "Hi", isComplete: true, usage: TokenUsage(inputTokens: 3, outputTokens: 2)))),
            ]
            let snapshot = SessionSnapshot(sessionId: "restore-456", items: items)
            await persistence.save(snapshot)

            let loaded = try #require(await persistence.load(id: "restore-456"))
            let session = Session.restore(from: loaded)

            #expect(session.sessionId == "restore-456")
            #expect(session.items.count == 2)

            let msg = try #require(session.items[0].content.userMessage)
            #expect(msg.text == "Hello")
        }

        @Test("Load most recent returns latest session")
        func loadMostRecentReturnsLatestSession() async throws {
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
    }

    @Suite("Round-trip")
    struct RoundTrip {
        @Test("Round-trip preserves content")
        @MainActor func roundTripPreservesContent() async throws {
            let persistence = InMemorySessionPersistence()

            let session = Session()
            session.sessionId = "round-trip"
            session.appendUserMessage("Question?")
            session.beginAssistantMessage()
            session.applyDelta("Answer.")
            session.completeAssistantMessage(usage: TokenUsage(inputTokens: 10, outputTokens: 8))
            session.appendSystemEvent(SystemEvent(kind: .sessionStarted, message: "Session started"))

            try await session.save(to: persistence)

            let snapshot = try #require(await persistence.load(id: "round-trip"))
            let restored = Session.restore(from: snapshot)

            #expect(restored.items.count == 3)

            let msg = try #require(restored.items[1].content.assistantMessage)
            #expect(msg.text == "Answer.")
            #expect(msg.isComplete)
            #expect(msg.usage.inputTokens == 10)
        }

        @Test("Round-trip preserves interrupted flag")
        func roundTripPreservesInterruptedFlag() async throws {
            let persistence = InMemorySessionPersistence()

            let snapshot = SessionSnapshot(
                sessionId: "interrupted",
                items: [TimelineItem(content: .userMessage(UserMessage(text: "Hi")))],
                wasInterrupted: true
            )
            await persistence.save(snapshot)

            let loaded = await persistence.load(id: "interrupted")
            #expect(loaded?.wasInterrupted == true)
        }
    }

    @Suite("Filtering")
    struct Filtering {
        @Test("Save filters transient error events")
        @MainActor func saveFiltersTransientErrorEvents() async throws {
            let persistence = InMemorySessionPersistence()

            let session = Session()
            session.sessionId = "filter-test"
            session.appendUserMessage("Hello")
            session.appendSystemEvent(SystemEvent(kind: .error, message: "Connection lost"))
            session.appendSystemEvent(SystemEvent(kind: .sessionStarted, message: "Session started"))

            try await session.save(to: persistence)

            let snapshot = try #require(await persistence.load(id: "filter-test"))
            #expect(snapshot.items.count == 2)

            for item in snapshot.items {
                if let event = item.content.system {
                    #expect(event.kind != .error)
                }
            }
        }
    }

    @Test("Delete removes session")
    func deleteRemovesSession() async throws {
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

    @Test("Corrupted items are skipped during decoding")
    func corruptedItemsSkippedDuringDecoding() throws {
        // Simulate a session with one valid item and one with an unknown content type
        let json = """
        {
            "sessionId": "lossy",
            "items": [
                {
                    "id": "11111111-1111-1111-1111-111111111111",
                    "timestamp": "2026-01-01T00:00:00Z",
                    "content": {"userMessage": {"_0": {"text": "Hello"}}}
                },
                {
                    "id": "22222222-2222-2222-2222-222222222222",
                    "timestamp": "2026-01-01T00:00:01Z",
                    "content": {"unknownType": {"_0": {"data": "corrupted"}}}
                },
                {
                    "id": "33333333-3333-3333-3333-333333333333",
                    "timestamp": "2026-01-01T00:00:02Z",
                    "content": {"userMessage": {"_0": {"text": "Still here"}}}
                }
            ],
            "savedAt": "2026-01-01T00:00:00Z"
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(SessionSnapshot.self, from: Data(json.utf8))
        #expect(snapshot.items.count == 2)
        let first = try #require(snapshot.items[0].content.userMessage)
        #expect(first.text == "Hello")
        let second = try #require(snapshot.items[1].content.userMessage)
        #expect(second.text == "Still here")
    }

    @Test("Snapshot without interrupted field decodes as false")
    func snapshotWithoutInterruptedFieldDecodesAsFalse() throws {
        let json = """
        {
            "sessionId": "legacy",
            "items": [],
            "savedAt": "2026-01-01T00:00:00Z"
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let snapshot = try decoder.decode(SessionSnapshot.self, from: Data(json.utf8))
        #expect(!snapshot.wasInterrupted)
        #expect(snapshot.sessionId == "legacy")
    }
}
