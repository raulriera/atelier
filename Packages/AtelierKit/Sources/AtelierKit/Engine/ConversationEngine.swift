public protocol ConversationEngine: Sendable {
    func send(message: String, model: ModelConfiguration, sessionId: String?) -> AsyncThrowingStream<StreamEvent, Error>
}
