import SwiftUI
import AtelierDesign
import AtelierKit

struct ConversationWindow: View {
    @Bindable var fileAccessStore: FileAccessStore
    var sessionPersistence: SessionPersistence
    var workingDirectory: URL?
    @State private var session = Session()
    @State private var draft = ""
    @State private var selectedModel: ModelConfiguration = .default
    @State private var streamingTask: Task<Void, Never>?
    @State private var cliAvailable = true
    @State private var showingFolderAccess = false
    @State private var showingContextFiles = false
    @State private var activeContextFiles: [ContextFile] = []
    @State private var showInspector = false
    @State private var selectedToolEvent: ToolUseEvent?
    @State private var showComposeField = false
    @State private var toolPayloads: [String: ToolPayload] = [:]
    @Environment(\.controlActiveState) private var controlActiveState
    @State private var unreadCount = 0
    @State private var approvalServer: ApprovalServer?
    @State private var approvalObserverTask: Task<Void, Never>?
    @State private var distillationTask: Task<Void, Never>?

    private let engine: CLIEngine = CLIEngine()

    var body: some View {
        NavigationStack {
            TimelineView(session: session, selectedToolID: selectedToolEvent?.id, onSelectTool: { event in
                    if selectedToolEvent?.id == event.id {
                        selectedToolEvent = nil
                    } else {
                        selectedToolEvent = event
                        showInspector = true
                    }
                }, onApprovalDecision: { id, decision in
                    handleApprovalDecision(id: id, decision: decision)
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
            ToolbarItem(placement: .automatic) {
                Button {
                    startNewConversation()
                } label: {
                    Label("New Conversation", systemImage: "plus.message")
                }
                .keyboardShortcut("t", modifiers: [.command, .shift])
                .disabled(session.isStreaming)
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    showingFolderAccess.toggle()
                } label: {
                    Label("Folder Access", systemImage: "folder")
                }
                .badge(fileAccessStore.entries.count)
                .help("Folder Access")
                .popover(isPresented: $showingFolderAccess) {
                    FolderAccessCard(fileAccessStore: fileAccessStore)
                        .padding(Spacing.sm)
                }
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    showingContextFiles.toggle()
                } label: {
                    Label("Context Files", systemImage: "doc.text")
                }
                .badge(activeContextFiles.count)
                .help("Context Files")
                .popover(isPresented: $showingContextFiles) {
                    ContextFilesCard(files: activeContextFiles)
                        .padding(Spacing.sm)
                }
            }
            ToolbarItem(placement: .automatic) {
                ModelPickerView(selection: $selectedModel)
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    showInspector.toggle()
                } label: {
                    Label("Inspector", systemImage: "sidebar.right")
                }
                .help("Toggle Inspector")
            }
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
            // Clean up distillation
            distillationTask?.cancel()
            distillationTask = nil
            // Clean up approval server
            approvalObserverTask?.cancel()
            approvalObserverTask = nil
            if let server = approvalServer {
                Task { await server.denyAllPending(); await server.stop() }
            }
        }
        .onChange(of: controlActiveState) { _, newState in
            if newState == .key {
                unreadCount = 0
                NSApp.dockTile.badgeLabel = nil
            }
        }
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""

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

        // Discover context files fresh on every send so edits take effect immediately.
        var injectedPrompt: String?
        if let cwd = workingDirectory {
            let discovered = ContextFileLoader.discover(from: cwd)
            activeContextFiles = discovered
            injectedPrompt = ContextFileLoader.contentForInjection(from: discovered)
        }

        startStreaming(message: text, appendSystemPrompt: injectedPrompt)
    }

    private func startStreaming(message: String, appendSystemPrompt: String? = nil) {
        streamingTask = Task {
            let socketPath = await approvalServer?.socketPath
            let stream = engine.send(message: message, model: selectedModel, sessionId: session.sessionId, workingDirectory: workingDirectory, appendSystemPrompt: appendSystemPrompt, approvalSocketPath: socketPath)
            do {
                for try await event in stream {
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
                        session.completeToolUse(id: id)
                    case .toolResultReceived(let id, let output):
                        session.applyToolResult(id: id, output: output)
                    case .messageComplete(let usage):
                        session.completeAssistantMessage(usage: usage)

                        if controlActiveState != .key {
                            unreadCount += 1
                            NSApp.requestUserAttention(.informationalRequest)
                            NSApp.dockTile.badgeLabel = "\(unreadCount)"
                        }

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

                        try? await session.save(to: sessionPersistence)
                        triggerDistillation()
                    case .error(let engineError):
                        session.handleError(engineError)
                        try? await session.save(to: sessionPersistence)
                    }
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

    private func stopGeneration() {
        streamingTask?.cancel()
        streamingTask = nil
        session.clearPendingMessages()
        session.completeAssistantMessage(usage: TokenUsage())
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

    /// Minimum meaningful items before distillation is worth running.
    private static let minimumItemsForDistillation = 4

    private func triggerDistillation() {
        guard let cwd = workingDirectory else { return }
        guard session.pendingMessages.isEmpty else { return }

        let items = session.items
        var meaningfulCount = 0
        for item in items {
            switch item.content {
            case .userMessage, .assistantMessage, .toolUse:
                meaningfulCount += 1
                if meaningfulCount >= Self.minimumItemsForDistillation { break }
            case .system, .approval:
                continue
            }
        }
        guard meaningfulCount >= Self.minimumItemsForDistillation else { return }
        guard let summary = ConversationSummarizer.summarize(items) else { return }

        distillationTask?.cancel()
        distillationTask = Task.detached {
            let store = MemoryStore(projectRoot: cwd)
            let existing = store.readLearnings()
            let engine = DistillationEngine()
            let result = await engine.distill(
                conversationSummary: summary,
                existingLearnings: existing,
                workingDirectory: cwd
            )
            if let result {
                try? store.writeLearnings(result)
            }
        }
    }

    private func startNewConversation() {
        streamingTask?.cancel()
        streamingTask = nil
        let captured = session.snapshot()
        withAnimation(Motion.appear) {
            session.reset()
        }
        if let captured {
            let persistence = sessionPersistence
            Task { try? await persistence.save(captured) }
        }
    }
}
