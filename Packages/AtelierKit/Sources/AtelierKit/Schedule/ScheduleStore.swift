import Foundation
import os

/// Persists and manages the list of scheduled tasks.
///
/// Pure data layer — CRUD, JSON persistence, and launchd agent sync.
/// Every mutation calls ``persist()`` then ``syncAgent()`` to keep
/// the launchd agent in sync with the current task state.
public final class ScheduleStore {
    /// The current list of scheduled tasks.
    public private(set) var tasks: [ScheduledTask] = []

    private let persistenceURL: URL?
    private let agentManager: any LaunchAgentManaging

    private static let logger = Logger(
        subsystem: "com.atelier.kit",
        category: "Schedule"
    )

    /// Default persistence URL: `~/Library/Application Support/Atelier/schedules.json`.
    public static let defaultPersistenceURL: URL =
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Atelier/schedules.json")

    /// Creates a new schedule store.
    ///
    /// - Parameters:
    ///   - persistenceURL: File to persist task state. Pass `nil` for in-memory only (tests/previews).
    ///   - agentManager: The launch agent manager to use for syncing the launchd plist.
    public init(persistenceURL: URL? = nil, agentManager: some LaunchAgentManaging = LaunchAgentManager()) {
        self.persistenceURL = persistenceURL
        self.agentManager = agentManager
    }

    /// Loads persisted tasks from disk.
    public func load() {
        guard let url = persistenceURL,
              let data = try? Data(contentsOf: url) else {
            Self.logger.debug("No persisted schedule data found")
            return
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        guard let loaded = try? decoder.decode([ScheduledTask].self, from: data) else {
            Self.logger.warning("Failed to decode schedules.json")
            return
        }

        tasks = loaded
        Self.logger.info("Loaded \(loaded.count) scheduled task(s)")
    }

    /// Returns tasks whose `projectPath` matches the given path.
    public func tasks(forProjectPath path: String) -> [ScheduledTask] {
        tasks.filter { $0.projectPath == path }
    }

    // MARK: - CRUD

    /// Adds a new scheduled task.
    ///
    /// - Parameter task: The task to add.
    public func add(_ task: ScheduledTask) {
        tasks.append(task)
        didMutate()
        Self.logger.info("Added task '\(task.name)'")
    }

    /// Updates an existing scheduled task.
    ///
    /// - Parameter task: The updated task (matched by `id`).
    public func update(_ task: ScheduledTask) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index] = task
        didMutate()
        Self.logger.info("Updated task '\(task.name)'")
    }

    /// Removes a scheduled task by ID.
    ///
    /// - Parameter id: The ID of the task to remove.
    public func remove(_ id: UUID) {
        tasks.removeAll { $0.id == id }
        didMutate()
        Self.logger.debug("Removed task \(id)")
    }

    /// Toggles the pause state of a scheduled task.
    ///
    /// - Parameter id: The ID of the task to toggle.
    public func togglePause(_ id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].isPaused.toggle()
        didMutate()
        Self.logger.debug("Toggled pause for task \(id): \(self.tasks[index].isPaused)")
    }

    // MARK: - Execution

    /// Runs a task immediately via `claude -p`, bypassing launchd.
    ///
    /// - Parameter id: The ID of the task to run.
    public func runNow(_ id: UUID) async {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        let task = tasks[index]

        Self.logger.info("Running task '\(task.name)' now")

        let succeeded = await Self.executeProcess(for: task)

        tasks[index].lastRunDate = Date()
        tasks[index].lastRunSucceeded = succeeded
        persist()

        await ScheduleNotifier.postCompletion(
            taskName: task.name,
            succeeded: succeeded,
            logPath: task.logURL.path
        )
    }

    /// Launches the CLI process on a background thread to avoid blocking the caller.
    ///
    /// Both stdout and stderr are written to the task's log file so the agent
    /// can read it later and help the user diagnose failures.
    private static func executeProcess(for task: ScheduledTask) async -> Bool {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let logURL = task.logURL
                let logDirectory = logURL.deletingLastPathComponent()
                try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)

                // Truncate existing log for this run
                FileManager.default.createFile(atPath: logURL.path, contents: nil)
                let logHandle = try? FileHandle(forWritingTo: logURL)

                let claudePath = CLIDiscovery.findCLI()
                let process = Process()
                process.executableURL = URL(fileURLWithPath: claudePath)

                var arguments = ["-p", task.prompt, "--output-format", "json", "--max-turns", "20"]
                if let model = task.model {
                    arguments += ["--model", model]
                }
                process.arguments = arguments
                process.currentDirectoryURL = URL(fileURLWithPath: task.projectPath)
                process.standardOutput = logHandle ?? FileHandle.nullDevice
                process.standardError = logHandle ?? FileHandle.nullDevice

                do {
                    try process.run()
                    process.waitUntilExit()
                    try? logHandle?.close()
                    continuation.resume(returning: process.terminationStatus == 0)
                } catch {
                    logger.error("Failed to launch claude for task '\(task.name)': \(error.localizedDescription)")
                    try? logHandle?.close()
                    continuation.resume(returning: false)
                }
            }
        }
    }

    // MARK: - Preview

    /// Sample store populated with preview tasks (no persistence, no agent sync).
    public static var preview: ScheduleStore {
        let store = ScheduleStore()
        store.tasks = [
            ScheduledTask(
                name: "Morning briefing",
                description: "Summarize overnight changes and today's calendar",
                prompt: "Review recent changes and summarize what happened overnight. Include today's calendar events.",
                schedule: .daily(hour: 8, minute: 0),
                projectPath: "/Users/demo/Projects/research"
            ),
            ScheduledTask(
                name: "Weekly report",
                description: "Generate a weekly progress report from commit history",
                prompt: "Generate a weekly progress report from the last 7 days of commits.",
                schedule: .weekly(weekday: 5, hour: 17, minute: 0),
                projectPath: "/Users/demo/Projects/research",
                lastRunDate: Date().addingTimeInterval(-86400),
                lastRunSucceeded: true
            ),
            ScheduledTask(
                name: "Paused task",
                description: "A task that is currently paused",
                prompt: "This task is paused.",
                schedule: .hourly,
                projectPath: "/Users/demo/Projects/notes",
                isPaused: true
            ),
        ]
        return store
    }

    // MARK: - Private

    private func didMutate() {
        persist()
        syncAgent()
    }

    private func persist() {
        guard let url = persistenceURL else { return }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(tasks) else {
            Self.logger.warning("Failed to encode scheduled tasks")
            return
        }

        // Ensure parent directory exists
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        try? data.write(to: url, options: .atomic)
        Self.logger.debug("Persisted \(self.tasks.count) task(s)")
    }

    private func syncAgent() {
        let intervals = tasks
            .filter { !$0.isPaused && $0.schedule != .manual }
            .compactMap(\.schedule.calendarIntervalDictionary)

        do {
            if intervals.isEmpty {
                try agentManager.uninstall()
            } else {
                try agentManager.install(calendarIntervals: intervals)
            }
        } catch {
            Self.logger.error("Failed to sync launch agent: \(error.localizedDescription)")
        }
    }
}
