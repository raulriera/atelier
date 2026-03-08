import Foundation
import os

/// Interface for managing the launchd Launch Agent plist.
public protocol LaunchAgentManaging: Sendable {
    func install(calendarIntervals: [[String: Int]]) throws
    func uninstall() throws
}

/// Manages a single launchd Launch Agent plist for all scheduled tasks.
///
/// The plist lives at `~/Library/LaunchAgents/com.atelier.scheduler.plist`
/// and uses `AssociatedBundleIdentifiers` so it appears as "Atelier" in
/// System Settings > Login Items.
public struct LaunchAgentManager: LaunchAgentManaging {
    /// The launchd agent label.
    static let label = "com.atelier.scheduler"
    /// The app bundle identifier used for `AssociatedBundleIdentifiers`.
    static let bundleIdentifier = "com.atelier"

    private static let logger = Logger(
        subsystem: "com.atelier.kit",
        category: "Schedule"
    )

    /// Creates a new launch agent manager.
    public init() {}

    /// The plist path: `~/Library/LaunchAgents/com.atelier.scheduler.plist`.
    public var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/\(Self.label).plist")
    }

    /// Installs or updates the Launch Agent with the given calendar intervals.
    ///
    /// Each interval corresponds to one active task's schedule.
    /// The helper binary reads `schedules.json` at runtime to determine
    /// which task(s) are due.
    ///
    /// - Parameter calendarIntervals: Array of launchd `StartCalendarInterval` dictionaries.
    public func install(calendarIntervals: [[String: Int]]) throws {
        guard !calendarIntervals.isEmpty else {
            try uninstall()
            return
        }

        let plist = buildPlist(calendarIntervals: calendarIntervals)

        // Ensure LaunchAgents directory exists
        let directory = plistURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // Unload existing agent if present (ignore errors if not loaded)
        if FileManager.default.fileExists(atPath: plistURL.path) {
            unloadAgent()
        }

        // Write the plist
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: plistURL, options: .atomic)

        // Load the agent
        loadAgent()

        Self.logger.info("Installed launch agent with \(calendarIntervals.count) interval(s)")
    }

    /// Removes the Launch Agent plist and unloads it.
    public func uninstall() throws {
        guard FileManager.default.fileExists(atPath: plistURL.path) else { return }

        unloadAgent()

        try FileManager.default.removeItem(at: plistURL)

        Self.logger.info("Uninstalled launch agent")
    }

    /// Builds the plist dictionary for the Launch Agent.
    ///
    /// - Parameter calendarIntervals: Array of `StartCalendarInterval` dictionaries.
    /// - Returns: A plist-compatible dictionary.
    func buildPlist(calendarIntervals: [[String: Int]]) -> [String: Any] {
        let helperPath = CLIEngine.bundledHelperPath(named: "atelier-scheduler")
            ?? Bundle.main.bundleURL
                .appendingPathComponent("Contents/Helpers/atelier-scheduler")
                .path

        let logsDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Atelier")

        return [
            "Label": Self.label,
            "AssociatedBundleIdentifiers": [Self.bundleIdentifier],
            "ProgramArguments": [helperPath],
            "WorkingDirectory": "/tmp",
            "StartCalendarInterval": calendarIntervals,
            "StandardOutPath": logsDirectory.appendingPathComponent("scheduler.log").path,
            "StandardErrorPath": logsDirectory.appendingPathComponent("scheduler.err").path,
        ]
    }

    // MARK: - Private

    private func loadAgent() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["load", plistURL.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }

    private func unloadAgent() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["unload", plistURL.path]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try? process.run()
        process.waitUntilExit()
    }
}
