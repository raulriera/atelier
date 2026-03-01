import Foundation

@Observable
public final class Session {
    public private(set) var items: [TimelineItem] = []
    public private(set) var activeAssistantText: String = ""
    public private(set) var isStreaming: Bool = false
    public private(set) var isThinking: Bool = false
    public private(set) var thinkingText: String = ""
    public var sessionId: String?

    private var activeItemID: UUID?

    public init() {}

    /// Creates a snapshot of the current session and saves it to persistence.
    ///
    /// Transient system events (errors) are filtered out — they don't need
    /// to survive a relaunch.
    @MainActor
    public func save(to persistence: SessionPersistence) async throws {
        guard let sessionId else { return }

        let persistableItems = items.filter { item in
            if case .system(let event) = item.content, event.kind == .error {
                return false
            }
            return true
        }

        let snapshot = SessionSnapshot(
            sessionId: sessionId,
            items: persistableItems
        )
        try await persistence.save(snapshot)
    }

    /// Restores a session from a previously saved snapshot.
    @MainActor
    public static func restore(from snapshot: SessionSnapshot) -> Session {
        let session = Session()
        session.sessionId = snapshot.sessionId
        session.items = snapshot.items
        return session
    }

    /// Resets all session state to start a new conversation.
    @MainActor
    public func reset() {
        items = []
        activeAssistantText = ""
        activeItemID = nil
        isStreaming = false
        isThinking = false
        thinkingText = ""
        sessionId = nil
    }

    @MainActor
    public func appendUserMessage(_ text: String) {
        let item = TimelineItem(content: .userMessage(UserMessage(text: text)))
        items.append(item)
    }

    @MainActor
    public func beginAssistantMessage() {
        let item = TimelineItem(content: .assistantMessage(AssistantMessage()))
        activeItemID = item.id
        activeAssistantText = ""
        isStreaming = true
        items.append(item)
    }

    @MainActor
    public func beginThinking() {
        isThinking = true
        thinkingText = ""
    }

    @MainActor
    public func applyThinkingDelta(_ text: String) {
        thinkingText += text
    }

    @MainActor
    public func applyDelta(_ text: String) {
        if isThinking {
            isThinking = false
        }
        activeAssistantText += text
    }

    @MainActor
    public func completeAssistantMessage(usage: TokenUsage) {
        guard let id = activeItemID,
              let index = items.firstIndex(where: { $0.id == id }) else { return }

        let trimmedText = activeAssistantText.trimmingCharacters(in: .whitespacesAndNewlines)
        items[index].content = .assistantMessage(
            AssistantMessage(text: trimmedText, isComplete: true, usage: usage)
        )
        activeAssistantText = ""
        activeItemID = nil
        isStreaming = false
        isThinking = false
        thinkingText = ""
    }

    @MainActor
    public func appendSystemEvent(_ event: SystemEvent) {
        let item = TimelineItem(content: .system(event))
        items.append(item)
    }

    @MainActor
    public func handleError(_ error: EngineError) {
        let message: String
        switch error {
        case .cliNotFound:
            message = "Claude CLI not found. Install it from claude.ai/download."
        case .processFailure(let code, let stderr):
            message = "Process exited with code \(code): \(stderr)"
        case .decodingError(let detail):
            message = "Failed to parse response: \(detail)"
        case .cliError(let detail):
            message = detail
        }

        appendSystemEvent(SystemEvent(kind: .error, message: message))
        activeAssistantText = ""
        activeItemID = nil
        isStreaming = false
        isThinking = false
        thinkingText = ""
    }
}
