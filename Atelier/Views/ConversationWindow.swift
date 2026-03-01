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
        TimelineView(session: session)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                ComposeField(text: $draft) {
                    sendMessage()
                }
                .disabled(!cliAvailable || session.isStreaming)
                .padding(Spacing.md)
            }
        .frame(minWidth: 400, minHeight: 500)
        .toolbar {
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
            } catch {
                if let engineError = error as? EngineError {
                    session.handleError(engineError)
                } else {
                    session.handleError(.cliError(error.localizedDescription))
                }
            }
        }
    }
}
