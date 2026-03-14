import Foundation

@MainActor
@Observable
public final class Session {
    public private(set) var items: [TimelineItem] = [] {
        didSet { visibleTimelineCacheVersion &+= 1 }
    }
    public private(set) var activeAssistantText: String = ""
    public private(set) var isStreaming: Bool = false
    public private(set) var isThinking: Bool = false
    public private(set) var thinkingText: String = ""
    public private(set) var pendingMessages: [String] = []
    public private(set) var cancelledItemIDs: Set<UUID> = []
    public var sessionId: String? {
        didSet {
            if sessionId != nil && sessionCreatedAt == nil {
                sessionCreatedAt = Date()
            }
        }
    }
    /// When this session was first created. Preserved across saves/restores.
    public private(set) var sessionCreatedAt: Date?

    private var activeItemID: UUID?
    private var activeToolIndices: [String: Int] = [:]
    private var hasToolUseSinceLastText: Bool = false
    private var pendingItemIDs: [UUID] = []
    /// The item ID of the user message whose response is currently streaming.
    /// Set by `appendUserMessage` / `dequeuePendingMessage`, cleared on completion.
    /// Used by `clearPendingMessages` to cancel the active message when the user stops.
    private var activeUserItemID: UUID?

    // MARK: - Task State

    private var cachedTaskEntries: [TaskEntry] = []
    private var cachedHasActiveTasks: Bool = false
    private var taskCacheVersion: UInt = 0
    private var taskCacheValidVersion: UInt = .max

    /// Aggregated task entries derived from all task tool events in the conversation.
    public var taskEntries: [TaskEntry] {
        rebuildTaskCacheIfNeeded()
        return cachedTaskEntries
    }

    /// Whether there are active (non-completed) tasks.
    public var hasActiveTasks: Bool {
        rebuildTaskCacheIfNeeded()
        return cachedHasActiveTasks
    }

    private func rebuildTaskCacheIfNeeded() {
        guard taskCacheVersion != taskCacheValidVersion else { return }
        let allTaskEvents = items.compactMap { item -> ToolUseEvent? in
            guard case .toolUse(let event) = item.content, event.isTaskOperation else { return nil }
            return event
        }
        cachedTaskEntries = TaskEntry.buildList(from: allTaskEvents)
        cachedHasActiveTasks = cachedTaskEntries.contains(where: \.isActive)
        taskCacheValidVersion = taskCacheVersion
    }

    /// Marks any pending or in-progress tasks as cancelled.
    ///
    /// Called when the assistant turn ends so stale tasks don't appear
    /// stuck with a spinner. The cancelled status is an ephemeral overlay
    /// on the cache — not persisted into the event stream. A future cache
    /// rebuild (next turn) will re-derive state from the raw events, but
    /// by then the card is either dismissed or replaced by new tasks.
    private func cancelActiveTasks() {
        rebuildTaskCacheIfNeeded()
        guard cachedHasActiveTasks else { return }
        for i in cachedTaskEntries.indices where cachedTaskEntries[i].isActive {
            cachedTaskEntries[i].status = .cancelled
        }
        cachedHasActiveTasks = false
    }

    // MARK: - Plan Review State

    private var cachedPlanReviewEntries: [PlanReviewEntry] = []
    private var planCacheVersion: UInt = 0
    private var planCacheValidVersion: UInt = .max

    /// Aggregated plan review entries derived from all timeline items.
    public var planReviewEntries: [PlanReviewEntry] {
        rebuildPlanCacheIfNeeded()
        return cachedPlanReviewEntries
    }

    /// Returns the resolution status for a given ExitPlanMode tool event.
    /// Returns `.pending` when no entry is found.
    public func planResolution(for toolEventID: String) -> ApprovalEvent.Status {
        rebuildPlanCacheIfNeeded()
        return cachedPlanReviewEntries.first { $0.id == toolEventID }?.resolution ?? .pending
    }

    /// Returns the plan file path for a given ExitPlanMode tool event.
    public func planFilePath(for toolEventID: String) -> String? {
        rebuildPlanCacheIfNeeded()
        return cachedPlanReviewEntries.first { $0.id == toolEventID }?.filePath
    }

    private func rebuildPlanCacheIfNeeded() {
        guard planCacheVersion != planCacheValidVersion else { return }
        cachedPlanReviewEntries = PlanReviewEntry.buildList(from: items)
        planCacheValidVersion = planCacheVersion
    }

    /// Invalidates all derived caches so the next access rebuilds.
    private func invalidateDerivedCaches() {
        taskCacheVersion &+= 1
        planCacheVersion &+= 1
        visibleTimelineCacheVersion &+= 1
    }

    // MARK: - Visible Timeline Cache

    private var cachedVisibleTimelineItems: [TimelineItem] = []
    private var visibleTimelineCacheVersion: UInt = 0
    private var visibleTimelineCacheValidVersion: UInt = .max

    /// Visible items with internal operations filtered out, for the timeline.
    public var visibleTimelineItems: [TimelineItem] {
        rebuildVisibleTimelineCacheIfNeeded()
        return cachedVisibleTimelineItems
    }

    private func rebuildVisibleTimelineCacheIfNeeded() {
        guard visibleTimelineCacheVersion != visibleTimelineCacheValidVersion else { return }
        cachedVisibleTimelineItems = items.filter { item in
            switch item.content {
            case .toolUse(let event):
                return !event.isTaskOperation && !event.isAskUserOperation && !event.isPlanOperation
            case .approval(let event):
                // ExitPlanMode approvals are handled by PlanReviewCard instead.
                return event.toolName != ApprovalEvent.exitPlanModeToolName
            default:
                return true
            }
        }
        visibleTimelineCacheValidVersion = visibleTimelineCacheVersion
    }

    private func appendItem(_ item: TimelineItem) {
        items.append(item)
        invalidateDerivedCaches()
    }

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

        // Title: first user message text, truncated.
        let title = persistableItems.lazy.compactMap { item -> String? in
            guard case .userMessage(let msg) = item.content, !msg.text.isEmpty else { return nil }
            let line = msg.text.prefix(80)
            return line.count < msg.text.count ? line + "…" : String(line)
        }.first ?? ""

        return SessionSnapshot(
            sessionId: sessionId,
            items: persistableItems,
            createdAt: sessionCreatedAt,
            title: title,
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
        session.sessionCreatedAt = snapshot.createdAt
        session.sessionId = snapshot.sessionId
        session.items = snapshot.items.compactMap { item in
            guard isPersistable(item) else { return nil }

            // A tool that was still running when the app quit is stale;
            // also cache input properties for all tool events on restore.
            if case .toolUse(var event) = item.content {
                var cleaned = item
                if event.status == .running {
                    event.status = .completed
                }
                event.cacheInputProperties()
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

        case .askUser(let event):
            // Only persist answered ask-user events — pending ones are transient
            return event.status != .pending

        case .userMessage:
            return true

        case .taskCompletion:
            // Re-derived from schedules.json on each launch
            return false
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
        sessionCreatedAt = nil
        pendingMessages = []
        pendingItemIDs = []
        activeUserItemID = nil
        cancelledItemIDs = []
        activeToolIndices = [:]
        hasToolUseSinceLastText = false

        cachedTaskEntries = []
        cachedHasActiveTasks = false
        taskCacheVersion = 0
        taskCacheValidVersion = .max
        cachedPlanReviewEntries = []
        planCacheVersion = 0
        planCacheValidVersion = .max
        cachedVisibleTimelineItems = []
        visibleTimelineCacheVersion = 0
        visibleTimelineCacheValidVersion = .max
    }

    @MainActor
    public func appendUserMessage(_ text: String, attachments: [FileAttachment] = []) {
        let item = TimelineItem(content: .userMessage(UserMessage(text: text, attachments: attachments)))
        activeUserItemID = item.id
        appendItem(item)
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
        appendItem(item)
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
        appendItem(item)
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
        cancelActiveTasks()

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
        appendItem(item)
        activeToolIndices[id] = items.count - 1
        hasToolUseSinceLastText = true
    }

    @MainActor
    public func applyToolInputDelta(id: String, json: String) {
        guard let index = activeToolIndices[id],
              case .toolUse(var event) = items[index].content else { return }
        event.inputJSON += json
        items[index].content = .toolUse(event)
        invalidateDerivedCaches()
    }

    /// Caches input properties once the input JSON is fully streamed (content_block_stop)
    /// while keeping the tool in `.running` state until the result arrives.
    @MainActor
    public func finalizeToolInput(id: String) {
        guard let index = activeToolIndices[id],
              case .toolUse(var event) = items[index].content else { return }
        event.cacheInputProperties()
        items[index].content = .toolUse(event)
    }

    @MainActor
    public func applyToolResult(id: String, output: String) {
        guard let index = toolIndex(for: id),
              case .toolUse(var event) = items[index].content else { return }
        event.resultOutput += output
        items[index].content = .toolUse(event)
        invalidateDerivedCaches()
    }

    @MainActor
    public func completeToolUse(id: String) {
        guard let index = toolIndex(for: id),
              case .toolUse(var event) = items[index].content else { return }
        event.status = .completed
        event.cacheInputProperties()
        items[index].content = .toolUse(event)
        activeToolIndices.removeValue(forKey: id)
        invalidateDerivedCaches()
    }

    /// Looks up a tool event index by checking `activeToolIndices` first, falling back
    /// to a reverse scan. The fallback is needed because `finalizeToolInput` keeps tools
    /// in the dictionary, but `completeToolUse` removes them — so a subsequent
    /// `applyToolResult` for the same tool must scan.
    private func toolIndex(for id: String) -> Int? {
        if let index = activeToolIndices[id] { return index }
        return items.lastIndex(where: {
            if case .toolUse(let event) = $0.content { return event.id == id }
            return false
        })
    }

    /// Returns the MCP tool name for a given tool event ID, or nil if not found.
    @MainActor
    public func toolName(for id: String) -> String? {
        guard let index = toolIndex(for: id),
              case .toolUse(let event) = items[index].content else { return nil }
        return event.name
    }

    // MARK: - Tool Approval

    @MainActor
    public func beginApproval(id: String, toolName: String, inputJSON: String) {
        let event = ApprovalEvent(id: id, toolName: toolName, inputJSON: inputJSON)
        let item = TimelineItem(content: .approval(event))
        appendItem(item)
    }

    /// Returns the approval event with the given ID, regardless of status.
    @MainActor
    public func approvalEvent(for id: String) -> ApprovalEvent? {
        for item in items.reversed() {
            if case .approval(let event) = item.content, event.id == id {
                return event
            }
        }
        return nil
    }

    /// Returns the first pending approval event matching the given tool name.
    @MainActor
    public func pendingApproval(toolName: String) -> ApprovalEvent? {
        for item in items.reversed() {
            if case .approval(let event) = item.content,
               event.toolName == toolName,
               event.status == .pending {
                return event
            }
        }
        return nil
    }

    /// Denies the pending ExitPlanMode approval if one exists, using the
    /// given message as the denial reason. Called when the user sends a
    /// message while a plan review is waiting — the message serves as
    /// their feedback.
    ///
    /// - Returns: The approval ID that was denied, or `nil` if no pending
    ///   plan approval existed.
    @MainActor
    @discardableResult
    public func denyPendingPlanApproval(reason: String) -> String? {
        guard let approval = pendingApproval(toolName: ApprovalEvent.exitPlanModeToolName) else { return nil }
        resolveApproval(id: approval.id, decision: .deny(reason: reason))
        return approval.id
    }

    /// Dismisses the pending ask-user event if one exists, using the given
    /// message as the custom text response. Called when the user sends a
    /// message while an ask-user card is waiting — the message supersedes
    /// the card interaction.
    ///
    /// - Returns: The event ID that was dismissed, or `nil` if no pending
    ///   ask-user existed.
    @MainActor
    @discardableResult
    public func dismissPendingAskUser(customText: String) -> String? {
        for index in items.indices.reversed() {
            if case .askUser(var event) = items[index].content,
               event.status == .pending {
                event.selectedIndex = AskUserEvent.customTextIndex
                event.customText = customText
                event.status = .answered
                event.answeredAt = Date()
                items[index].content = .askUser(event)
                return event.id
            }
        }
        return nil
    }

    @MainActor
    public func resolveApproval(id: String, decision: ApprovalDecision) {
        guard let index = items.lastIndex(where: {
            if case .approval(let event) = $0.content { return event.id == id }
            return false
        }), case .approval(var event) = items[index].content else { return }

        switch decision {
        case .allow, .allowForSession:
            event.status = .approved
        case .deny:
            event.status = .denied
        }
        event.decidedAt = Date()
        items[index].content = .approval(event)
        planCacheVersion &+= 1
    }

    // MARK: - Ask User

    @MainActor
    public func beginAskUser(id: String, question: String, options: [AskUserEvent.Option]) {
        let event = AskUserEvent(id: id, question: question, options: options)
        let item = TimelineItem(content: .askUser(event))
        appendItem(item)
    }

    @MainActor
    public func resolveAskUser(id: String, selectedIndex: Int, customText: String? = nil) {
        guard let index = items.lastIndex(where: {
            if case .askUser(let event) = $0.content { return event.id == id }
            return false
        }), case .askUser(var event) = items[index].content else { return }

        event.selectedIndex = selectedIndex
        event.customText = customText
        event.status = .answered
        event.answeredAt = Date()
        items[index].content = .askUser(event)
    }

    /// Dismisses all pending approval and ask-user events.
    ///
    /// Called when the conversation is stopped so interactive cards collapse
    /// instead of staying actionable after the CLI process is gone.
    @MainActor
    public func dismissPendingInteractions() {
        let now = Date()
        for index in items.indices {
            switch items[index].content {
            case .approval(var event) where event.status == .pending:
                event.status = .dismissed
                event.decidedAt = now
                items[index].content = .approval(event)
            case .askUser(var event) where event.status == .pending:
                event.status = .answered
                event.selectedIndex = AskUserEvent.customTextIndex
                event.customText = "Dismissed"
                event.answeredAt = now
                items[index].content = .askUser(event)
            default:
                continue
            }
        }
        planCacheVersion &+= 1
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
        event.cacheInputProperties()
        items[index].content = .toolUse(event)
        invalidateDerivedCaches()
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
                event.cacheInputProperties()
                items[index].content = .toolUse(event)
            }
        }
        activeToolIndices.removeAll()
    }

    @MainActor
    public func appendSystemEvent(_ event: SystemEvent) {
        let item = TimelineItem(content: .system(event))
        appendItem(item)
    }

    @MainActor
    public func appendTaskCompletion(_ event: TaskCompletionEvent) {
        let item = TimelineItem(content: .taskCompletion(event))
        appendItem(item)
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
