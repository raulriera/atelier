import Foundation

@Observable
public final class Session {
    public private(set) var items: [TimelineItem] = []
    public private(set) var activeAssistantText: String = ""
    public private(set) var isStreaming: Bool = false
    public private(set) var isThinking: Bool = false
    public private(set) var thinkingText: String = ""
    public private(set) var pendingMessages: [String] = []
    public private(set) var cancelledItemIDs: Set<UUID> = []
    public var sessionId: String?

    private var activeItemID: UUID?
    private var activeToolIndices: [String: Int] = [:]
    private var hasToolUseSinceLastText: Bool = false
    private var pendingItemIDs: [UUID] = []
    /// The item ID of the user message whose response is currently streaming.
    /// Set by `appendUserMessage` / `dequeuePendingMessage`, cleared on completion.
    /// Used by `clearPendingMessages` to cancel the active message when the user stops.
    private var activeUserItemID: UUID?

    public init() {}

    /// Creates a snapshot of the current session and saves it to persistence.
    ///
    /// Only well-formed items are persisted. Transient items (errors, empty
    /// incomplete assistant messages, running tools) are cleaned up so we
    /// never write broken state to disk.
    @MainActor
    public func save(to persistence: SessionPersistence, wasInterrupted: Bool = false) async throws {
        guard let snapshot = snapshot(wasInterrupted: wasInterrupted) else { return }
        try await persistence.save(snapshot)
    }

    /// Captures the current session state as a snapshot without persisting it.
    ///
    /// Returns `nil` if the session has no ID (never connected to the CLI).
    @MainActor
    public func snapshot(wasInterrupted: Bool = false) -> SessionSnapshot? {
        guard let sessionId else { return nil }

        let persistableItems = items.filter { Self.isPersistable($0) && !cancelledItemIDs.contains($0.id) }

        return SessionSnapshot(
            sessionId: sessionId,
            items: persistableItems,
            wasInterrupted: wasInterrupted,
            pendingMessages: pendingMessages
        )
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
        // pendingMessages are not restored — the corresponding pendingItemIDs
        // aren't persisted, so dequeuePendingMessage() would crash. Pending
        // messages are transient state; the wasInterrupted flag handles the UX.
        return session
    }

    /// Returns `false` for items that should never be written to disk.
    private static func isPersistable(_ item: TimelineItem) -> Bool {
        switch item.content {
        case .system(let event):
            // Transient system events don't survive a relaunch
            return event.kind == .sessionStarted

        case .assistantMessage(let msg):
            // An incomplete message with no text is an orphaned placeholder
            if !msg.isComplete && msg.text.isEmpty { return false }
            return true

        case .toolUse:
            return true

        case .approval(let event):
            // Only persist resolved approvals — pending ones are transient
            return event.status != .pending

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
        pendingMessages = []
        pendingItemIDs = []
        activeUserItemID = nil
        cancelledItemIDs = []
        activeToolIndices = [:]
        hasToolUseSinceLastText = false
    }

    @MainActor
    public func appendUserMessage(_ text: String) {
        let item = TimelineItem(content: .userMessage(UserMessage(text: text)))
        activeUserItemID = item.id
        items.append(item)
    }

    /// Queues a message to be sent after the current response completes.
    ///
    /// The message appears in the timeline immediately as a user bubble,
    /// and is dispatched to the CLI when the current stream finishes.
    @MainActor
    public func enqueuePendingMessage(_ text: String) {
        let item = TimelineItem(content: .userMessage(UserMessage(text: text)))
        pendingMessages.append(text)
        pendingItemIDs.append(item.id)
        items.append(item)
    }

    /// Removes and returns the next queued message, or nil if the queue is empty.
    ///
    /// The corresponding user bubble remains in the timeline because the
    /// message is about to be dispatched to the CLI. The item ID is saved
    /// so it can be marked cancelled if the user stops generation before
    /// the response completes.
    @MainActor
    public func dequeuePendingMessage() -> String? {
        guard !pendingMessages.isEmpty else { return nil }
        activeUserItemID = pendingItemIDs.removeFirst()
        return pendingMessages.removeFirst()
    }

    /// Discards all queued messages and marks their user bubbles as
    /// cancelled so they render visually muted in the timeline.
    /// Also cancels any message that was just dispatched but whose
    /// response was stopped before completing.
    @MainActor
    public func clearPendingMessages() {
        if let active = activeUserItemID {
            cancelledItemIDs.insert(active)
        }
        cancelledItemIDs.formUnion(pendingItemIDs)
        pendingMessages.removeAll()
        pendingItemIDs.removeAll()
        activeUserItemID = nil
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
        activeUserItemID = nil
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
    public func applyToolResult(id: String, output: String) {
        // Tool results arrive after content_block_stop, so the tool is no longer
        // in activeToolIndices. Scan items from the end (most recent first).
        guard let index = items.lastIndex(where: {
            if case .toolUse(let event) = $0.content { return event.id == id }
            return false
        }), case .toolUse(var event) = items[index].content else { return }
        event.resultOutput += output
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

    // MARK: - Tool Approval

    @MainActor
    public func beginApproval(id: String, toolName: String, inputJSON: String) {
        let event = ApprovalEvent(id: id, toolName: toolName, inputJSON: inputJSON)
        let item = TimelineItem(content: .approval(event))
        items.append(item)
    }

    @MainActor
    public func resolveApproval(id: String, decision: ApprovalDecision) {
        guard let index = items.lastIndex(where: {
            if case .approval(let event) = $0.content { return event.id == id }
            return false
        }), case .approval(var event) = items[index].content else { return }

        switch decision {
        case .allow:
            event.status = .approved
        case .deny:
            event.status = .denied
        }
        event.decidedAt = Date()
        items[index].content = .approval(event)
    }

    // MARK: - Tool Payload Population

    /// Replaces lightweight tool stubs with full payload data loaded from the sidecar.
    ///
    /// After population the cached summaries are cleared so the live computed
    /// properties take over (they'll produce the same text from full data).
    @MainActor
    public func populateToolPayload(toolId: String, inputJSON: String, resultOutput: String) {
        guard let index = items.lastIndex(where: {
            if case .toolUse(let event) = $0.content { return event.id == toolId }
            return false
        }), case .toolUse(var event) = items[index].content else { return }

        event.inputJSON = inputJSON
        event.resultOutput = resultOutput
        event.cachedInputSummary = ""
        event.cachedResultSummary = ""
        items[index].content = .toolUse(event)
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
        for (_, index) in activeToolIndices {
            if case .toolUse(var event) = items[index].content {
                event.status = .completed
                items[index].content = .toolUse(event)
            }
        }
        activeToolIndices.removeAll()
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
        activeUserItemID = nil
        clearPendingMessages()
        completeAllActiveTools()
        hasToolUseSinceLastText = false
    }
}
