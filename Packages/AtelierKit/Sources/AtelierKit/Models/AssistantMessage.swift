public struct AssistantMessage: Sendable, Codable {
    public var text: String
    public var isComplete: Bool
    public var usage: TokenUsage

    public init(
        text: String = "",
        isComplete: Bool = false,
        usage: TokenUsage = TokenUsage()
    ) {
        self.text = text
        self.isComplete = isComplete
        self.usage = usage
    }
}
