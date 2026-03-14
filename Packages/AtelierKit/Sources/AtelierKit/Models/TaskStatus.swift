/// Status of a task in the task list.
public enum TaskStatus: String, Sendable {
    case pending
    case inProgress = "in_progress"
    case completed
    case deleted
    case cancelled

    /// Human-readable description for VoiceOver.
    public var accessibilityDescription: String {
        switch self {
        case .pending: "pending"
        case .inProgress: "in progress"
        case .completed: "completed"
        case .deleted: "deleted"
        case .cancelled: "cancelled"
        }
    }
}

/// A single todo item parsed from a `TodoWrite` tool event.
public struct TodoItem: Sendable {
    public let id: String
    public let content: String
    public let status: TaskStatus

    init?(dict: [String: Any], index: Int) {
        guard let content = dict["content"] as? String else { return nil }
        // The CLI doesn't always include an id — fall back to the array index.
        self.id = dict["id"] as? String ?? String(index)
        self.content = content
        self.status = (dict["status"] as? String).flatMap(TaskStatus.init(rawValue:)) ?? .pending
    }
}
