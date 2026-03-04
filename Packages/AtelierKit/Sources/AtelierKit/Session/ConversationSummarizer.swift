/// Converts a conversation timeline into a plain-text summary for distillation.
public enum ConversationSummarizer {

    /// Maximum characters per assistant message before truncation.
    private static let maxMessageLength = 2000

    /// Default cap on items to include (takes the tail of the conversation).
    public static let defaultMaxItems = 100

    /// Produces a plain-text summary of the conversation, or `nil` if empty.
    ///
    /// Includes user messages, completed assistant messages, and completed tool summaries.
    /// Excludes thinking, streaming deltas, system events, and running tools.
    public static func summarize(
        _ items: [TimelineItem],
        maxItems: Int = defaultMaxItems
    ) -> String? {
        let tail = items.suffix(maxItems)
        var lines: [String] = []

        for item in tail {
            switch item.content {
            case .userMessage(let msg):
                lines.append("User: \(msg.text)")

            case .assistantMessage(let msg):
                guard msg.isComplete else { continue }
                let text = msg.text
                if text.count > maxMessageLength {
                    lines.append("Assistant: \(text.prefix(maxMessageLength))...")
                } else {
                    lines.append("Assistant: \(text)")
                }

            case .toolUse(let tool):
                guard tool.status == .completed else { continue }
                let summary = tool.inputSummary
                let result = tool.resultSummary
                if !summary.isEmpty || !result.isEmpty {
                    var line = "Tool(\(tool.displayName))"
                    if !summary.isEmpty { line += ": \(summary)" }
                    if !result.isEmpty { line += " → \(result)" }
                    lines.append(line)
                }

            case .system, .approval, .askUser:
                continue
            }
        }

        guard !lines.isEmpty else { return nil }
        return lines.joined(separator: "\n")
    }
}
