import Foundation

public protocol ConversationEngine: Sendable {
    func send(message: String, model: ModelConfiguration, sessionId: String?, workingDirectory: URL?, appendSystemPrompt: String?, approvalSocketPath: String?, enabledCapabilities: [EnabledCapability]) -> AsyncThrowingStream<StreamEvent, Error>
}
