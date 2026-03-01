import SwiftUI
import AtelierDesign
import AtelierKit

struct ConversationWindow: View {
    @Bindable var fileAccessStore: FileAccessStore
    var sessionPersistence: SessionPersistence
    @State private var session = Session()
    @State private var draft = ""
    @State private var selectedModel: ModelConfiguration = .default
    @State private var streamingTask: Task<Void, Never>?
    @State private var cliAvailable = true
    @State private var showingFolderAccess = false

    private let engine: CLIEngine = CLIEngine()

    var body: some View {
        ZStack(alignment: .top) {
            TimelineView(session: session)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    ComposeField(
                        text: $draft,
                        isStreaming: session.isStreaming,
                        onSubmit: { sendMessage() },
                        onStop: { stopGeneration() }
                    )
                    .disabled(!cliAvailable)
                    .padding(Spacing.md)
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
        .frame(minWidth: 400, minHeight: 500)
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .onKeyPress(.escape) {
            guard session.isStreaming else { return .ignored }
            stopGeneration()
            return .handled
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    startNewConversation()
                } label: {
                    Label("New Conversation", systemImage: "plus.message")
                }
                .keyboardShortcut("n", modifiers: .command)
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
                ModelPickerView(selection: $selectedModel)
            }
        }
        .task {
            if let snapshot = try? await sessionPersistence.loadMostRecent() {
                session = Session.restore(from: snapshot)
            }
        }
        .onAppear {
            cliAvailable = CLIEngine.isAvailable
            if !cliAvailable {
                session.appendSystemEvent(
                    SystemEvent(kind: .error, message: "Claude CLI not found. Install it from claude.ai/download.")
                )
            }
        }
    }

    private func sendMessage() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        draft = ""

        withAnimation(Motion.appear) {
            session.appendUserMessage(text)
            session.beginAssistantMessage()
        }

        streamingTask = Task {
            let stream = engine.send(message: text, model: selectedModel, sessionId: session.sessionId)
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
        if !session.items.isEmpty {
            Task {
                try? await session.save(to: sessionPersistence)
            }
        }
        streamingTask?.cancel()
        streamingTask = nil
        withAnimation(Motion.appear) {
            session.reset()
        }
    }
}
