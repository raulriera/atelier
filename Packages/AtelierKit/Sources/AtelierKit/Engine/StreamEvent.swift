public enum StreamEvent: Sendable {
    case sessionStarted(String)
    case textDelta(String)
    case thinkingStarted
    case thinkingDelta(String)
    case toolUseStarted(id: String, name: String)
    case toolInputDelta(id: String, json: String)
    case toolUseFinished(id: String)
    case toolResultReceived(id: String, output: String)
    case messageComplete(TokenUsage)
    case error(EngineError)
}
