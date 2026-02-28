import SwiftUI
import AtelierDesign
import AtelierKit

struct ConversationWindow: View {
    @State private var session = Session()
    @State private var draft = ""
    @State private var selectedModel: ModelConfiguration = .default
    @State private var streamingTask: Task<Void, Never>?
    @State private var cliAvailable = true

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
                ModelPickerView(selection: $selectedModel)
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

        session.appendUserMessage(text)
        session.beginAssistantMessage()

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
                    case .error(let engineError):
                        session.handleError(engineError)
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
