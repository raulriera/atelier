public enum TimelineContent: Sendable, Codable {
    case userMessage(UserMessage)
    case assistantMessage(AssistantMessage)
    case system(SystemEvent)
    case toolUse(ToolUseEvent)
}
