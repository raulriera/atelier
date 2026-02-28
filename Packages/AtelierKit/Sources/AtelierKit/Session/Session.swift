import Foundation

@Observable
public final class Session {
    public private(set) var items: [TimelineItem] = []
    public private(set) var activeAssistantText: String = ""
    public private(set) var isStreaming: Bool = false
    public var sessionId: String?

    private var activeItemID: UUID?

    public init() {}

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
    public func applyDelta(_ text: String) {
        activeAssistantText += text
    }

    @MainActor
    public func completeAssistantMessage(usage: TokenUsage) {
        guard let id = activeItemID,
              let index = items.firstIndex(where: { $0.id == id }) else { return }

        items[index].content = .assistantMessage(
            AssistantMessage(text: activeAssistantText, isComplete: true, usage: usage)
        )
        activeAssistantText = ""
        activeItemID = nil
        isStreaming = false
    }

    @MainActor
    public func appendSystemEvent(_ event: SystemEvent) {
        let item = TimelineItem(content: .system(event))
        items.append(item)
    }

    @MainActor
    public func handleError(_ error: EngineError) {
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
    }
}
