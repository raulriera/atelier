/// A task completion entry for the conversation timeline.
///
/// Created when a scheduled task finishes running. Contains the
/// task name and structured result for display in the timeline
/// and inspector detail.
public struct TaskCompletionEvent: Sendable, Codable {
    /// The scheduled task's user-facing name.
    public var name: String
    /// Structured result parsed from the task's log file.
    public var result: TaskRunResult

    public init(name: String, result: TaskRunResult) {
        self.name = name
        self.result = result
    }

    /// Plain-english message for the timeline.
    public var message: String {
        "\"\(name)\" \(result.userSummary)"
    }
}
