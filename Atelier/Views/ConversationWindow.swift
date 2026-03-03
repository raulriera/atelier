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
                })
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
                    .padding(Spacing.md)
                    .opacity(showComposeField ? 1 : 0)
                    .animation(Motion.appear, value: showComposeField)
                }
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(.bar)
                        .frame(height: Spacing.xxl)
                        .ignoresSafeArea(edges: .bottom)
                        .mask {
                            LinearGradient(
                                colors: [.clear, .black],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        }
                        .allowsHitTesting(false)
                }
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
            // WORKAROUND: SwiftUI .inspector() on macOS expands the window instead of
            // compressing content in-place (unlike AppKit NSSplitViewController which
            // uses holdingPriority). Wrapping in NavigationStack prevents the window
            // from growing. File FB to Apple.
            .inspector(isPresented: $showInspector) {
                InspectorSidebar(selectedTool: selectedToolEvent)
                    .inspectorColumnWidth(min: 260, ideal: 320, max: 480)
            }
        }
        .frame(minWidth: 600, minHeight: 500)
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
        }
    }

    // MARK: - Actions

    private func sendMessage() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""

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
            let stream = engine.send(message: message, model: selectedModel, sessionId: session.sessionId, workingDirectory: workingDirectory, appendSystemPrompt: appendSystemPrompt)
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
                        try? await session.save(to: sessionPersistence)
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
        session.completeAssistantMessage(usage: TokenUsage())
        Task {
            try? await session.save(to: sessionPersistence)
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
