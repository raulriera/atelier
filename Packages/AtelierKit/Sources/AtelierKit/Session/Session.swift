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
    private var activeToolIndices: [String: Int] = [:]
    private var hasToolUseSinceLastText: Bool = false

    public init() {}

    /// Creates a snapshot of the current session and saves it to persistence.
    ///
    /// Only well-formed items are persisted. Transient items (errors, empty
    /// incomplete assistant messages, running tools) are cleaned up so we
    /// never write broken state to disk.
    @MainActor
    public func save(to persistence: SessionPersistence) async throws {
        guard let sessionId else { return }

        let persistableItems = items.filter { Self.isPersistable($0) }

        let snapshot = SessionSnapshot(
            sessionId: sessionId,
            items: persistableItems
        )
        try await persistence.save(snapshot)
    }

    /// Restores a session from a previously saved snapshot.
    ///
    /// Applies the same persistability filter to clean up any broken data
    /// written by older versions, and marks stale running tools as completed.
    @MainActor
    public static func restore(from snapshot: SessionSnapshot) -> Session {
        let session = Session()
        session.sessionId = snapshot.sessionId
        session.items = snapshot.items.compactMap { item in
            guard isPersistable(item) else { return nil }

            // A tool that was still running when the app quit is stale
            if case .toolUse(var event) = item.content, event.status == .running {
                var cleaned = item
                event.status = .completed
                cleaned.content = .toolUse(event)
                return cleaned
            }
            return item
        }
        return session
    }

    /// Returns `false` for items that should never be written to disk.
    private static func isPersistable(_ item: TimelineItem) -> Bool {
        switch item.content {
        case .system(let event):
            // Transient errors don't survive a relaunch
            return event.kind != .error

        case .assistantMessage(let msg):
            // An incomplete message with no text is an orphaned placeholder
            if !msg.isComplete && msg.text.isEmpty { return false }
            return true

        case .toolUse:
            return true

        case .userMessage:
            return true
        }
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
        activeToolIndices = [:]
        hasToolUseSinceLastText = false
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

        // After tool use, start a fresh assistant message for the next text turn
        if hasToolUseSinceLastText {
            finalizeCurrentAssistantMessage()
            beginAssistantMessage()
            hasToolUseSinceLastText = false
        }

        activeAssistantText += text
    }

    @MainActor
    public func completeAssistantMessage(usage: TokenUsage) {
        if let id = activeItemID,
           let index = items.firstIndex(where: { $0.id == id }) {
            let trimmedText = activeAssistantText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedText.isEmpty {
                items.remove(at: index)
            } else {
                items[index].content = .assistantMessage(
                    AssistantMessage(text: trimmedText, isComplete: true, usage: usage)
                )
            }
        }
        activeAssistantText = ""
        activeItemID = nil
        isStreaming = false
        isThinking = false
        thinkingText = ""
        completeAllActiveTools()
        hasToolUseSinceLastText = false
    }

    // MARK: - Tool Use

    @MainActor
    public func beginToolUse(id: String, name: String) {
        // Finalize any in-progress assistant text before the tool card
        finalizeCurrentAssistantMessage()

        let event = ToolUseEvent(id: id, name: name)
        let item = TimelineItem(content: .toolUse(event))
        items.append(item)
        activeToolIndices[id] = items.count - 1
        hasToolUseSinceLastText = true
    }

    @MainActor
    public func applyToolInputDelta(id: String, json: String) {
        guard let index = activeToolIndices[id],
              case .toolUse(var event) = items[index].content else { return }
        event.inputJSON += json
        items[index].content = .toolUse(event)
    }

    @MainActor
    public func completeToolUse(id: String) {
        guard let index = activeToolIndices[id],
              case .toolUse(var event) = items[index].content else { return }
        event.status = .completed
        items[index].content = .toolUse(event)
        activeToolIndices.removeValue(forKey: id)
    }

    // MARK: - Private Helpers

    /// Finalizes the current assistant message. Removes the item if it has no text.
    @MainActor
    private func finalizeCurrentAssistantMessage() {
        guard let id = activeItemID,
              let index = items.firstIndex(where: { $0.id == id }) else { return }

        let trimmedText = activeAssistantText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedText.isEmpty {
            items.remove(at: index)
            // Adjust tool indices that shifted down after removal
            for (toolId, toolIndex) in activeToolIndices where toolIndex > index {
                activeToolIndices[toolId] = toolIndex - 1
            }
        } else {
            items[index].content = .assistantMessage(
                AssistantMessage(text: trimmedText, isComplete: true, usage: TokenUsage())
            )
        }
        activeAssistantText = ""
        activeItemID = nil
    }

    @MainActor
    private func completeAllActiveTools() {
        for (toolId, index) in activeToolIndices {
            if case .toolUse(var event) = items[index].content {
                event.status = .completed
                items[index].content = .toolUse(event)
            }
            activeToolIndices.removeValue(forKey: toolId)
        }
    }

    @MainActor
    public func appendSystemEvent(_ event: SystemEvent) {
        let item = TimelineItem(content: .system(event))
        items.append(item)
    }

    @MainActor
    public func handleError(_ error: EngineError) {
        // Save or remove the active assistant item
        if let id = activeItemID,
           let index = items.firstIndex(where: { $0.id == id }) {
            let trimmedText = activeAssistantText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedText.isEmpty {
                items.remove(at: index)
            } else {
                items[index].content = .assistantMessage(
                    AssistantMessage(text: trimmedText, isComplete: true, usage: TokenUsage())
                )
            }
        }

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
        completeAllActiveTools()
        hasToolUseSinceLastText = false
    }
}
