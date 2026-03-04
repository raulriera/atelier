/// A single entry in an aggregated task checklist, built from timeline tool events.
public struct TaskEntry: Sendable, Identifiable {
    public let id: String
    public var subject: String
    public var status: TaskStatus

    public init(id: String, subject: String, status: TaskStatus) {
        self.id = id
        self.subject = subject
        self.status = status
    }

    /// SF Symbol name for the current status.
    public var iconName: String {
        switch status {
        case .completed: "checkmark.circle.fill"
        case .inProgress: "arrow.circlepath"
        case .pending, .deleted: "circle"
        }
    }

    /// Whether the task is currently in progress.
    public var isActive: Bool {
        status == .inProgress
    }
}

// MARK: - Building task state from timeline events

extension TaskEntry {
    /// Builds a task list from a sequence of task tool events.
    ///
    /// Supports two formats:
    /// - **TodoWrite**: each call contains the full list in `{"todos": [...]}`
    ///   — only the last TodoWrite matters.
    /// - **TaskCreate/TaskUpdate**: incremental — creates add rows, updates modify status.
    public static func buildList(from events: [ToolUseEvent]) -> [TaskEntry] {
        // If there are any TodoWrite events, use the last one (it has complete state).
        if let lastTodoWrite = events.last(where: { $0.name == "TodoWrite" }),
           let items = lastTodoWrite.todoItems {
            return items
                .filter { $0.status != .deleted }
                .map { TaskEntry(id: $0.id, subject: $0.content, status: $0.status) }
        }

        // Fall back to TaskCreate/TaskUpdate accumulation.
        var tasks: [String: TaskEntry] = [:]
        var order: [String] = []
        var nextId = 1

        for event in events {
            switch event.name {
            case "TaskCreate":
                let id = String(nextId)
                nextId += 1
                let subject = event.taskSubject ?? "Task \(id)"
                tasks[id] = TaskEntry(id: id, subject: subject, status: .pending)
                order.append(id)

            case "TaskUpdate":
                if let taskId = event.taskId {
                    if let raw = event.taskStatus, let newStatus = TaskStatus(rawValue: raw) {
                        tasks[taskId]?.status = newStatus
                    }
                    if let newSubject = event.taskSubject {
                        tasks[taskId]?.subject = newSubject
                    }
                }

            default:
                break
            }
        }

        return order.compactMap { id in
            guard let task = tasks[id], task.status != .deleted else { return nil }
            return task
        }
    }
}
