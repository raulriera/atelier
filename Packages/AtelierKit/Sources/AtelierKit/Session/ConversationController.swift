import Foundation
#if canImport(AppKit)
import AppKit
#endif

/// Owns the conversation lifecycle: streaming, approvals, ask-user flow,
/// session persistence, and capability health. Views bind to its
/// `@Observable` properties without containing business logic.
@MainActor @Observable
public final class ConversationController {

    // MARK: - Observable state

    public private(set) var session = Session()
    public private(set) var capabilityHealthMonitor = CapabilityHealthMonitor()
    public private(set) var cliAvailable = true
    public private(set) var activeContextFiles: [ContextFile] = []
    public internal(set) var toolPayloads: [String: ToolPayload] = [:]
    public var selectedToolEvent: ToolUseEvent?
    public var selectedModel: ModelConfiguration = .default
    public private(set) var sessionList: [SessionSnapshotMetadata] = []

    /// Tools the user approved for the lifetime of this conversation.
    public private(set) var sessionApprovedTools: Set<String> = []

    /// File paths the user dropped into the conversation, auto-approved for Read.
    private var allowedAttachmentPaths: Set<String> = []

    // MARK: - Dependencies

    private let engine: any ConversationEngine
    public let capabilityStore: CapabilityStore
    private let sessionPersistence: SessionPersistence
    public let workingDirectory: URL?

    // MARK: - Internal state

    private var streamingTask: Task<Void, Never>?
    private var saveTask: Task<Void, Never>?
    private var fingerprintTask: Task<Void, Never>?
    private var approvalServer: ApprovalServer?
    private var approvalObserverTask: Task<Void, Never>?
    private var askUserObserverTask: Task<Void, Never>?

    // MARK: - Init

    public init(
        engine: any ConversationEngine = CLIEngine(),
        capabilityStore: CapabilityStore,
        sessionPersistence: SessionPersistence,
        workingDirectory: URL?
    ) {
        self.engine = engine
        self.capabilityStore = capabilityStore
        self.sessionPersistence = sessionPersistence
        self.workingDirectory = workingDirectory
    }

    // MARK: - Lifecycle

    /// Call once from the view's `.task` modifier to restore session,
    /// start the approval server, and discover context files.
    public func start() async {
        if let snapshot = try? await sessionPersistence.loadMostRecent() {
            session = Session.restore(from: snapshot)
            if snapshot.wasInterrupted {
                session.appendSystemEvent(
                    SystemEvent(kind: .info, message: "Session interrupted — send a message to continue.")
                )
            }
            if let id = session.sessionId {
                toolPayloads = (try? await sessionPersistence.loadToolPayloads(sessionId: id)) ?? [:]
            }
        }

        await refreshSessionList()

        guard approvalServer == nil else { return }
        let server = ApprovalServer()
        approvalServer = server
        try? await server.start()

        approvalObserverTask = Task {
            for await request in await server.requests {
                if sessionApprovedTools.contains(request.toolName) {
                    await server.respond(requestId: request.id, decision: .allow)
                    continue
                }
                session.beginApproval(
                    id: request.id,
                    toolName: request.toolName,
                    inputJSON: request.inputJSON
                )
                requestUserAttentionIfNeeded()
            }
        }

        askUserObserverTask = Task {
            for await request in await server.askUserRequests {
                let options = request.options.map {
                    AskUserEvent.Option(label: $0.label, description: $0.description)
                }
                session.beginAskUser(
                    id: request.id,
                    question: request.question,
                    options: options
                )
                requestUserAttentionIfNeeded()
            }
        }
    }

    /// Call once from `.onAppear` for synchronous setup (CLI check, hooks, context files).
    public func checkAvailability() {
        cliAvailable = CLIEngine.isAvailable
        if !cliAvailable {
            session.appendSystemEvent(
                SystemEvent(kind: .error, message: "Claude CLI not found. Install it from claude.ai/download.")
            )
        }
        if let cwd = workingDirectory {
            activeContextFiles = ContextFileLoader.discover(from: cwd)
            try? HooksManager(projectRoot: cwd).install()

            // Generate a context file in the background if one doesn't exist yet.
            // generateIfMissing is a no-op when the file already exists.
            // Uses Haiku for a natural-language summary when the CLI is available.
            let root = cwd
            let runner: CLIRunner? = CLIDiscovery.isAvailable
                ? ProcessCLIRunner(executablePath: CLIDiscovery.findCLI())
                : nil
            fingerprintTask = Task.detached(priority: .utility) {
                await ProjectFingerprinter.generateIfMissing(at: root, runner: runner)
            }
        }
    }

    /// Call from `.onDisappear` to tear down streaming, approval server, and persist.
    public func shutdown() {
        let wasStreaming = session.isStreaming
        if wasStreaming {
            streamingTask?.cancel()
            streamingTask = nil
            session.completeAssistantMessage(usage: TokenUsage())
        }
        fingerprintTask?.cancel()
        fingerprintTask = nil
        saveTask?.cancel()
        saveTask = nil
        if let captured = session.snapshot(wasInterrupted: wasStreaming) {
            try? sessionPersistence.saveImmediately(captured)
        }
        approvalObserverTask?.cancel()
        approvalObserverTask = nil
        askUserObserverTask?.cancel()
        askUserObserverTask = nil
        if let server = approvalServer {
            Task { await server.denyAllPending(); await server.stop() }
        }
    }

    // MARK: - Sending messages

    /// Sends a user message, handling plan denial, ask-user dismissal,
    /// message queuing, context injection, and streaming.
    public func sendMessage(_ text: String, attachments: [FileAttachment] = []) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !attachments.isEmpty else { return }

        if let deniedID = session.denyPendingPlanApproval(reason: trimmed) {
            if let server = approvalServer {
                Task { await server.respond(requestId: deniedID, decision: .deny(reason: trimmed)) }
            }
        }

        if let dismissedID = session.dismissPendingAskUser(customText: trimmed) {
            if let server = approvalServer {
                Task { await server.respondAskUser(requestId: dismissedID, selectedIndex: AskUserEvent.customTextIndex, selectedLabel: trimmed) }
            }
        }

        // Build the CLI message: user text + file paths for Claude to read
        let cliMessage = Self.buildCLIMessage(text: trimmed, attachments: attachments)

        // Register attachment paths for auto-approval before the queueing check
        // so queued messages also get their files approved when eventually sent.
        for attachment in attachments {
            allowedAttachmentPaths.insert(attachment.url.standardizedFileURL.path)
        }

        if session.isStreaming {
            session.enqueuePendingMessage(cliMessage)
            return
        }

        // Attachments and text are separate timeline items (like iMessage):
        // first the attachment-only bubble, then the text bubble.
        if !attachments.isEmpty {
            session.appendUserMessage("", attachments: attachments)
        }
        if !trimmed.isEmpty {
            session.appendUserMessage(trimmed)
        }
        session.beginAssistantMessage()

        var promptParts: [String] = [SystemPrompt.coreInstructions, SystemPrompt.currentDate]
        if let cwd = workingDirectory {
            let discovered = ContextFileLoader.discover(from: cwd)
            activeContextFiles = discovered
            if let content = ContextFileLoader.contentForInjection(from: discovered) {
                promptParts.append(content)
            }
            if !ContextFileLoader.hasProjectContext(discovered) {
                promptParts.append(SystemPrompt.onboardingInstructions)
            }
        }
        if let capFragment = capabilityStore.systemPromptFragment() {
            promptParts.append(capFragment)
        }
        let injectedPrompt = promptParts.isEmpty ? nil : promptParts.joined(separator: "\n\n")

        startStreaming(message: cliMessage, appendSystemPrompt: injectedPrompt)
    }

    /// Builds the message string sent to the CLI, appending file paths if attachments are present.
    private static func buildCLIMessage(text: String, attachments: [FileAttachment]) -> String {
        guard !attachments.isEmpty else { return text }
        let paths = attachments.map(\.url.path).joined(separator: "\n")
        if text.isEmpty {
            return "[Attached files]\n\(paths)"
        }
        return "\(text)\n\n[Attached files]\n\(paths)"
    }

    // MARK: - Stop

    public func stopGeneration() {
        streamingTask?.cancel()
        streamingTask = nil
        session.clearPendingMessages()
        session.completeAssistantMessage(usage: TokenUsage())
        session.dismissPendingInteractions()
        if let server = approvalServer {
            Task { await server.denyAllPending() }
        }
        scheduleSave()
    }

    // MARK: - Approvals

    public func handleApprovalDecision(id: String, toolName: String, decision: ApprovalDecision) {
        if case .allowForSession = decision {
            sessionApprovedTools.insert(toolName)
        }
        session.resolveApproval(id: id, decision: decision)
        if let server = approvalServer {
            Task { await server.respond(requestId: id, decision: decision) }
        }
    }

    public func handlePlanApprove() {
        guard let approval = session.pendingApproval(toolName: ApprovalEvent.exitPlanModeToolName) else { return }
        handleApprovalDecision(id: approval.id, toolName: approval.toolName, decision: .allow)
    }

    // MARK: - Ask user

    public func handleAskUserResponse(id: String, selectedIndex: Int, customText: String? = nil) {
        session.resolveAskUser(id: id, selectedIndex: selectedIndex, customText: customText)
        let selectedLabel: String
        if let item = session.items.last(where: {
            if case .askUser(let e) = $0.content { return e.id == id }
            return false
        }), case .askUser(let event) = item.content {
            selectedLabel = event.selectedLabel ?? "Unknown"
        } else {
            selectedLabel = "Unknown"
        }
        if let server = approvalServer {
            Task { await server.respondAskUser(requestId: id, selectedIndex: selectedIndex, selectedLabel: selectedLabel) }
        }
    }

    // MARK: - Capabilities

    public func enableCapability(_ id: String) {
        let name = capabilityStore.capabilities.first { $0.id == id }?.name ?? id
        capabilityStore.enable(id)
        session.appendSystemEvent(
            SystemEvent(kind: .info, message: "\(name) enabled. Try your request again.")
        )
    }

    // MARK: - Inspector

    /// Call when the selected tool changes to lazy-load its sidecar payload.
    public func loadToolPayloadIfNeeded(for toolID: String?) {
        guard let newID = toolID,
              let payload = toolPayloads[newID] else { return }
        session.populateToolPayload(toolId: newID, inputJSON: payload.inputJSON, resultOutput: payload.resultOutput)
        toolPayloads.removeValue(forKey: newID)
        if let item = session.items.last(where: {
            if case .toolUse(let e) = $0.content { return e.id == newID }
            return false
        }), case .toolUse(let updated) = item.content {
            selectedToolEvent = updated
        }
    }

    // MARK: - Session management

    public func startNewConversation() {
        let captured = teardownCurrentSession()
        if let captured {
            let persistence = sessionPersistence
            saveTask = Task {
                try? await persistence.save(captured)
                await self.refreshSessionList()
            }
        }
    }

    /// Switches to a previously saved session by ID.
    public func switchToSession(id: String) {
        // Don't switch to the already-active session.
        guard id != session.sessionId else { return }

        let captured = teardownCurrentSession()

        let persistence = sessionPersistence
        saveTask = Task {
            if let captured {
                try? await persistence.save(captured)
            }
            guard !Task.isCancelled else { return }
            if let snapshot = try? await persistence.load(id: id) {
                guard !Task.isCancelled else { return }
                session = Session.restore(from: snapshot)
                toolPayloads = (try? await persistence.loadToolPayloads(sessionId: id)) ?? [:]
            }
            await refreshSessionList()
        }
    }

    /// Tears down the current session: cancels tasks, snapshots state, and resets.
    @discardableResult
    private func teardownCurrentSession() -> SessionSnapshot? {
        streamingTask?.cancel()
        streamingTask = nil
        saveTask?.cancel()
        saveTask = nil
        let captured = session.snapshot()
        sessionApprovedTools.removeAll()
        allowedAttachmentPaths.removeAll()
        session.reset()
        capabilityHealthMonitor.reset()
        toolPayloads = [:]
        return captured
    }

    /// Reloads the list of saved sessions from persistence.
    public func refreshSessionList() async {
        let list = await sessionPersistence.list()
        // Sort by creation date, newest first — stable order that never shifts.
        sessionList = list.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Private

    /// Cancels any in-flight save and schedules a new one from the current session state.
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await session.save(to: sessionPersistence)
        }
    }

    private func startStreaming(message: String, appendSystemPrompt: String? = nil) {
        streamingTask?.cancel()
        streamingTask = Task {
            let socketPath = await approvalServer?.socketPath
            let capConfigs = capabilityStore.enabledCapabilityConfigs()
            let stream = engine.send(message: message, model: selectedModel, sessionId: session.sessionId, workingDirectory: workingDirectory, appendSystemPrompt: appendSystemPrompt, approvalSocketPath: socketPath, enabledCapabilities: capConfigs, allowedReadPaths: Array(allowedAttachmentPaths))
            do {
                for try await event in stream {
                    handleStreamEvent(event)
                }
                if session.isStreaming {
                    session.completeAssistantMessage(usage: TokenUsage())
                }
            } catch is CancellationError {
                // Intentional stop
            } catch {
                if let engineError = error as? EngineError {
                    session.handleError(engineError)
                } else {
                    session.handleError(.cliError(error.localizedDescription))
                }
            }
        }
    }

    private func handleStreamEvent(_ event: StreamEvent) {
        switch event {
        case .sessionStarted(let id):
            session.sessionId = id
        case .textDelta(let chunk):
            session.applyDelta(chunk)
        case .thinkingStarted:
            session.beginThinking()
        case .thinkingDelta(let chunk):
            session.applyThinkingDelta(chunk)
        case .toolUseStarted(let id, let name):
            session.beginToolUse(id: id, name: name)
        case .toolInputDelta(let id, let json):
            session.applyToolInputDelta(id: id, json: json)
        case .toolUseFinished(let id):
            session.finalizeToolInput(id: id)
        case .toolResultReceived(let id, let output, let isError):
            let toolName = session.toolName(for: id)
            session.applyToolResult(id: id, output: output)
            session.completeToolUse(id: id)
            if let toolName {
                if isError {
                    if let alert = capabilityHealthMonitor.recordFailure(toolName: toolName) {
                        session.appendSystemEvent(SystemEvent(kind: .info, message: alert))
                    }
                } else {
                    capabilityHealthMonitor.recordSuccess(toolName: toolName)
                }
            }
        case .messageComplete(let usage):
            handleMessageComplete(usage: usage)
        case .error(let engineError):
            session.handleError(engineError)
            scheduleSave()
        }
    }

    private func handleMessageComplete(usage: TokenUsage) {
        session.completeAssistantMessage(usage: usage)
        requestUserAttentionIfNeeded()

        if let queued = session.dequeuePendingMessage() {
            session.beginAssistantMessage()
            startStreaming(message: queued)
            return
        }

        scheduleSave()
    }

    private func requestUserAttentionIfNeeded() {
        #if canImport(AppKit)
        guard let app = NSApp, !app.isActive else { return }
        app.requestUserAttention(.informationalRequest)
        #endif
    }
}
