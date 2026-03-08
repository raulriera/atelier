import Foundation

/// A recurring task that runs on a schedule via launchd.
///
/// Each task has a prompt that is sent to `claude -p` at the scheduled time,
/// scoped to a specific project folder. Tasks can be paused without deleting them.
public struct ScheduledTask: Sendable, Codable, Identifiable {
    /// Unique identifier for this task.
    public let id: UUID
    /// Short user-facing name for the task.
    public var name: String
    /// Longer explanation of what the task does.
    public var description: String
    /// The prompt sent to `claude -p` when the task fires.
    public var prompt: String
    /// When the task should run.
    public var schedule: TaskSchedule
    /// Model CLI alias to use, or `nil` to use the default model.
    public var model: String?
    /// Absolute path to the project folder where the task runs.
    public var projectPath: String
    /// Whether the task is paused (skipped during scheduled runs).
    public var isPaused: Bool
    /// When the task last ran, if ever.
    public var lastRunDate: Date?
    /// Whether the last run succeeded, if ever run.
    public var lastRunSucceeded: Bool?
    /// Card color name from ``TaskColor``.
    public var colorName: String
    /// When the task was created.
    public var createdAt: Date

    /// The log file for this task's most recent run.
    ///
    /// Located at `~/Library/Logs/Atelier/tasks/{id}.log`.
    /// Contains both stdout and stderr from the CLI process,
    /// so the agent can read it and help the user fix failures.
    public var logURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Atelier/tasks/\(id.uuidString).log")
    }

    /// Creates a new scheduled task.
    public init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        prompt: String,
        schedule: TaskSchedule,
        model: String? = nil,
        projectPath: String,
        isPaused: Bool = false,
        lastRunDate: Date? = nil,
        lastRunSucceeded: Bool? = nil,
        colorName: String = TaskColor.defaultName,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.prompt = prompt
        self.schedule = schedule
        self.model = model
        self.projectPath = projectPath
        self.isPaused = isPaused
        self.lastRunDate = lastRunDate
        self.lastRunSucceeded = lastRunSucceeded
        self.colorName = colorName
        self.createdAt = createdAt
    }
}
