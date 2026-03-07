import SwiftUI
import AtelierDesign
import AtelierKit

struct ConversationWindow: View {
    @Bindable var fileAccessStore: FileAccessStore
    let capabilityStore: CapabilityStore
    var sessionPersistence: SessionPersistence
    var workingDirectory: URL?
    @State private var session = Session()
    @State private var capabilityHealthMonitor = CapabilityHealthMonitor()
    @State private var draft = ""
    @State private var selectedModel: ModelConfiguration = .default
    @State private var streamingTask: Task<Void, Never>?
    @State private var cliAvailable = true
    @State private var showingCapabilities = false
    @State private var showingContextFiles = false
    @State private var activeContextFiles: [ContextFile] = []
    @State private var showInspector = false
    @State private var selectedToolEvent: ToolUseEvent?
    @State private var showComposeField = false
    @State private var toolPayloads: [String: ToolPayload] = [:]
    @State private var approvalServer: ApprovalServer?
    @State private var approvalObserverTask: Task<Void, Never>?
    @State private var askUserObserverTask: Task<Void, Never>?


    private let engine: CLIEngine = CLIEngine()

    var body: some View {
        NavigationStack {
            TimelineView(session: session, capabilityStore: capabilityStore, selectedToolID: selectedToolEvent?.id, onSelectTool: { event in
                    if selectedToolEvent?.id == event.id {
                        selectedToolEvent = nil
                    } else {
                        selectedToolEvent = event
                        showInspector = true
                    }
                }, onApprovalDecision: { id, decision in
                    handleApprovalDecision(id: id, decision: decision)
                }, onAskUserResponse: { id, selectedIndex, customText in
                    handleAskUserResponse(id: id, selectedIndex: selectedIndex, customText: customText)
                }, onPlanApprove: {
                    handlePlanApprove()
                }, onEnableCapability: { id in
                    let name = capabilityStore.capabilities.first { $0.id == id }?.name ?? id
                    withAnimation(Motion.morph) {
                        capabilityStore.enable(id)
                        session.appendSystemEvent(
                            SystemEvent(kind: .info, message: "\(name) enabled. Try your request again.")
                        )
                    }
                })
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(.bar)
                        .frame(height: Spacing.xxl)
                        .mask {
                            LinearGradient(
                                stops: [
                                    .init(color: .black, location: 0),
                                    .init(color: .black, location: 0.5),
                                    .init(color: .clear, location: 1),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                        .ignoresSafeArea(edges: .top)
                        .allowsHitTesting(false)
                }
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    TaskListOverlay(session: session)
                        .padding(.bottom, Spacing.xs)
                }
                // WORKAROUND: NavigationStack (required for .inspector() to compress
                // content in-place) animates safeAreaInset content on first layout.
                // Keeping ComposeField always in the layout (stable safe area from
                // frame 1) and fading opacity avoids the position animation. Revisit.
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    ComposeField(
                        text: $draft,
                        isStreaming: session.isStreaming,
                        onSubmit: { sendMessage() },
                        onStop: { stopGeneration() }
                    )
                    .disabled(!cliAvailable)
                    .frame(maxWidth: Layout.readingWidth)
                    .padding(Spacing.md)
                    .background {
                        // Fade gradient behind (not on top of) compose field so
                        // text and button render at full brightness.
                        Rectangle()
                            .fill(.bar)
                            .mask {
                                LinearGradient(
                                    colors: [.clear, .black],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            }
                            .ignoresSafeArea(edges: .bottom)
                    }
                    .opacity(showComposeField ? 1 : 0)
                    .animation(Motion.appear, value: showComposeField)
                }
            // WORKAROUND: SwiftUI .inspector() on macOS expands the window instead of
            // compressing content in-place (unlike AppKit NSSplitViewController which
            // uses holdingPriority). Wrapping in NavigationStack prevents the window
            // from growing. File FB to Apple.
            .inspector(isPresented: $showInspector) {
                InspectorSidebar(selectedTool: selectedToolEvent)
                    .inspectorColumnWidth(min: 260, ideal: 320, max: 480)
            }
        }
        .frame(minWidth: Layout.minimumWindowWidth, minHeight: Layout.minimumWindowHeight)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .toolbar {
            ConversationToolbar(
                isStreaming: session.isStreaming,
                showingCapabilities: $showingCapabilities,
                showingContextFiles: $showingContextFiles,
                showInspector: $showInspector,
                selectedModel: $selectedModel,
                capabilityStore: capabilityStore,
                activeContextFiles: activeContextFiles,
                onNewConversation: startNewConversation
            )
        }
        .onKeyPress(.escape) {
            guard session.isStreaming else { return .ignored }
            stopGeneration()
            return .handled
        }
        .task {
            if let snapshot = try? await sessionPersistence.loadMostRecent() {
                session = Session.restore(from: snapshot)
                if snapshot.wasInterrupted {
                    session.appendSystemEvent(
                        SystemEvent(kind: .info, message: "Session interrupted — send a message to continue.")
                    )
                }
                // Preload sidecar payloads in background for on-demand inspector use
                if let id = session.sessionId {
                    toolPayloads = (try? await sessionPersistence.loadToolPayloads(sessionId: id)) ?? [:]
                }
            }

            // Start approval server (guard against SwiftUI re-invoking .task)
            guard approvalServer == nil else { return }
            let server = ApprovalServer()
            approvalServer = server
            try? await server.start()

            // Observe incoming approval requests
            approvalObserverTask = Task {
                for await request in await server.requests {
                    withAnimation(Motion.appear) {
                        session.beginApproval(
                            id: request.id,
                            toolName: request.toolName,
                            inputJSON: request.inputJSON
                        )
                    }
                    requestUserAttentionIfNeeded()
                }
            }

            // Observe incoming ask-user requests
            askUserObserverTask = Task {
                for await request in await server.askUserRequests {
                    let options = request.options.map {
                        AskUserEvent.Option(label: $0.label, description: $0.description)
                    }
                    withAnimation(Motion.appear) {
                        session.beginAskUser(
                            id: request.id,
                            question: request.question,
                            options: options
                        )
                    }
                    requestUserAttentionIfNeeded()
                }
            }

            // WORKAROUND continued: NavigationStack animates safeAreaInset content
            // on first layout. Wait for that to settle, then reveal ComposeField.
            // The scoped .animation(_:value:) on ComposeField handles the fade —
            // no withAnimation here to avoid giving NavigationStack an animation
            // context it can hijack for position changes.
            try? await Task.sleep(for: .milliseconds(160))
            showComposeField = true
        }
        .onChange(of: selectedToolEvent?.id) { _, newID in
            guard let newID,
                  let payload = toolPayloads[newID] else { return }
            session.populateToolPayload(toolId: newID, inputJSON: payload.inputJSON, resultOutput: payload.resultOutput)
            toolPayloads.removeValue(forKey: newID)
            // Refresh the selected event — it's a value-type copy that doesn't
            // see the mutation we just made inside session.items.
            if let item = session.items.last(where: {
                if case .toolUse(let e) = $0.content { return e.id == newID }
                return false
            }), case .toolUse(let updated) = item.content {
                selectedToolEvent = updated
            }
        }
        .onAppear {
            cliAvailable = CLIEngine.isAvailable
            if !cliAvailable {
                session.appendSystemEvent(
                    SystemEvent(kind: .error, message: "Claude CLI not found. Install it from claude.ai/download.")
                )
            }
            if let cwd = workingDirectory {
                activeContextFiles = ContextFileLoader.discover(from: cwd)
                try? HooksManager(projectRoot: cwd).install()
            }
        }
        .onDisappear {
            let wasStreaming = session.isStreaming
            if wasStreaming {
                streamingTask?.cancel()
                streamingTask = nil
                session.completeAssistantMessage(usage: TokenUsage())
            }
            if let captured = session.snapshot(wasInterrupted: wasStreaming) {
                try? sessionPersistence.saveImmediately(captured)
            }
            // Clean up approval server
            approvalObserverTask?.cancel()
            approvalObserverTask = nil
            askUserObserverTask?.cancel()
            askUserObserverTask = nil
            if let server = approvalServer {
                Task { await server.denyAllPending(); await server.stop() }
            }
        }
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""

        // If there's a pending plan approval, auto-deny it — the user's message
        // serves as their feedback on the plan. This must happen before the
        // streaming check because the CLI blocks while waiting for the approval.
        if let deniedID = session.denyPendingPlanApproval(reason: text) {
            if let server = approvalServer {
                Task { await server.respond(requestId: deniedID, decision: .deny(reason: text)) }
            }
        }

        // If there's a pending ask-user, dismiss it — the user's message
        // supersedes the card. This unblocks the CLI which is waiting for
        // the ask_user response on the socket.
        if let dismissedID = session.dismissPendingAskUser(customText: text) {
            if let server = approvalServer {
                Task { await server.respondAskUser(requestId: dismissedID, selectedIndex: AskUserEvent.customTextIndex, selectedLabel: text) }
            }
        }

        if session.isStreaming {
            withAnimation(Motion.appear) {
                session.enqueuePendingMessage(text)
            }
            return
        }

        withAnimation(Motion.appear) {
            session.appendUserMessage(text)
            session.beginAssistantMessage()
        }

        // Build the supplemental system prompt: core behavior + context files + capabilities.
        var promptParts: [String] = [SystemPrompt.coreInstructions]
        if let cwd = workingDirectory {
            let discovered = ContextFileLoader.discover(from: cwd)
            activeContextFiles = discovered
            if let content = ContextFileLoader.contentForInjection(from: discovered) {
                promptParts.append(content)
            }
        }
        if let capFragment = capabilityStore.systemPromptFragment() {
            promptParts.append(capFragment)
        }
        let injectedPrompt = promptParts.isEmpty ? nil : promptParts.joined(separator: "\n\n")

        startStreaming(message: text, appendSystemPrompt: injectedPrompt)
    }

    private func startStreaming(message: String, appendSystemPrompt: String? = nil) {
        streamingTask = Task {
            let socketPath = await approvalServer?.socketPath
            let capConfigs = capabilityStore.enabledCapabilityConfigs()
            let stream = engine.send(message: message, model: selectedModel, sessionId: session.sessionId, workingDirectory: workingDirectory, appendSystemPrompt: appendSystemPrompt, approvalSocketPath: socketPath, enabledCapabilities: capConfigs)
            do {
                for try await event in stream {
                    handleStreamEvent(event)
                }
                // If stream ends without messageComplete (e.g. empty response)
                if session.isStreaming {
                    session.completeAssistantMessage(usage: TokenUsage())
                }
            } catch is CancellationError {
                // Intentional stop — stopGeneration() already finalized state
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
            // Don't complete yet — the tool is still executing server-side.
            // Cache input properties now so cards can display descriptions while running.
            session.finalizeToolInput(id: id)
        case .toolResultReceived(let id, let output, let isError):
            let toolName = session.toolName(for: id)
            session.applyToolResult(id: id, output: output)
            session.completeToolUse(id: id)
            if let toolName {
                if isError {
                    if let alert = capabilityHealthMonitor.recordFailure(toolName: toolName) {
                        withAnimation(Motion.appear) {
                            session.appendSystemEvent(SystemEvent(kind: .info, message: alert))
                        }
                    }
                } else {
                    capabilityHealthMonitor.recordSuccess(toolName: toolName)
                }
            }
        case .messageComplete(let usage):
            handleMessageComplete(usage: usage)
        case .error(let engineError):
            session.handleError(engineError)
            Task { try? await session.save(to: sessionPersistence) }
        }
    }

    private func handleMessageComplete(usage: TokenUsage) {
        session.completeAssistantMessage(usage: usage)
        requestUserAttentionIfNeeded()

        // Dispatch queued message before saving — the save
        // suspends the main actor, which could let user input
        // bypass the queue while isStreaming is false.
        if let queued = session.dequeuePendingMessage() {
            withAnimation(Motion.appear) {
                session.beginAssistantMessage()
            }
            startStreaming(message: queued)
            return
        }

        Task {
            try? await session.save(to: sessionPersistence)
        }
    }

    private func stopGeneration() {
        streamingTask?.cancel()
        streamingTask = nil
        session.clearPendingMessages()
        session.completeAssistantMessage(usage: TokenUsage())
        withAnimation(Motion.morph) {
            session.dismissPendingInteractions()
        }
        if let server = approvalServer {
            Task { await server.denyAllPending() }
        }
        Task {
            try? await session.save(to: sessionPersistence)
        }
    }

    private func handleApprovalDecision(id: String, decision: ApprovalDecision) {
        withAnimation(Motion.morph) {
            session.resolveApproval(id: id, decision: decision)
        }
        if let server = approvalServer {
            Task { await server.respond(requestId: id, decision: decision) }
        }
    }

    private func handlePlanApprove() {
        guard let approval = session.pendingApproval(toolName: ApprovalEvent.exitPlanModeToolName) else { return }
        handleApprovalDecision(id: approval.id, decision: .allow)
    }

    private func handleAskUserResponse(id: String, selectedIndex: Int, customText: String? = nil) {
        withAnimation(Motion.morph) {
            session.resolveAskUser(id: id, selectedIndex: selectedIndex, customText: customText)
        }
        // Look up the label from the resolved event
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

    /// Bounces the dock icon when the app is not frontmost.
    private func requestUserAttentionIfNeeded() {
        guard !NSApp.isActive else { return }
        NSApp.requestUserAttention(.informationalRequest)
    }

    private func startNewConversation() {
        streamingTask?.cancel()
        streamingTask = nil
        let captured = session.snapshot()
        withAnimation(Motion.appear) {
            session.reset()
            capabilityHealthMonitor.reset()
        }
        if let captured {
            let persistence = sessionPersistence
            Task { try? await persistence.save(captured) }
        }
    }
}
