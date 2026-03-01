public enum StreamEvent: Sendable {
    case sessionStarted(String)
    case textDelta(String)
    case thinkingStarted
    case thinkingDelta(String)
    case messageComplete(TokenUsage)
    case error(EngineError)
}
