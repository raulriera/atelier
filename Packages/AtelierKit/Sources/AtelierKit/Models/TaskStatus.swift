/// Status of a task in the task list.
public enum TaskStatus: String, Sendable {
    case pending
    case inProgress = "in_progress"
    case completed
    case deleted

    /// Human-readable description for VoiceOver.
    public var accessibilityDescription: String {
        switch self {
        case .pending: "pending"
        case .inProgress: "in progress"
        case .completed: "completed"
        case .deleted: "deleted"
        }
    }
}

/// A single todo item parsed from a `TodoWrite` tool event.
public struct TodoItem: Sendable {
    public let id: String
    public let content: String
    public let status: TaskStatus

    init?(dict: [String: Any]) {
        guard let id = dict["id"] as? String,
              let content = dict["content"] as? String else { return nil }
        self.id = id
        self.content = content
        self.status = (dict["status"] as? String).flatMap(TaskStatus.init(rawValue:)) ?? .pending
    }
}
