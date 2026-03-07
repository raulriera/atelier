import Foundation
import os

/// Manages Atelier's hook registration in `.claude/settings.local.json`.
///
/// Hooks are the CLI's lifecycle event system. Atelier registers hooks to:
/// - Re-inject learnings after context compaction (`SessionStart[compact]`)
/// - Inject learnings on new sessions (`SessionStart[startup]`)
///
/// The manager merges Atelier's hooks with any user-defined hooks already in
/// the file, and can cleanly remove only Atelier's hooks on uninstall.
public struct HooksManager: Sendable {
    private static let logger = Logger(subsystem: "com.atelier.kit", category: "HooksManager")

    /// Marker to identify Atelier-managed hooks.
    static let statusMessagePrefix = "[Atelier]"

    /// The project root containing `.claude/`.
    public let projectRoot: URL

    public init(projectRoot: URL) {
        self.projectRoot = projectRoot
    }

    /// Path to `.claude/settings.local.json` within the project.
    var settingsURL: URL {
        projectRoot
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("settings.local.json")
    }

    /// Path to `.atelier/memory/learnings.md` within the project.
    private var learningsPath: String {
        projectRoot
            .appendingPathComponent(".atelier/memory/learnings.md")
            .path
    }

    /// Registers Atelier's hooks, preserving any user-defined hooks.
    ///
    /// Idempotent — calling multiple times produces the same result.
    public func install() throws {
        var settings = readSettings() ?? [String: Any]()
        var hooks = settings["hooks"] as? [String: Any] ?? [:]

        // Build Atelier hooks
        let atelierHooks = buildAtelierHooks()

        // Merge into each event, replacing existing Atelier hooks
        for (event, newEntries) in atelierHooks {
            var eventEntries = hooks[event] as? [[String: Any]] ?? []

            // Remove existing Atelier entries for this event
            eventEntries.removeAll { entry in
                isAtelierManaged(entry)
            }

            // Add new Atelier entries
            if let newArray = newEntries as? [[String: Any]] {
                eventEntries.append(contentsOf: newArray)
            }

            hooks[event] = eventEntries
        }

        settings["hooks"] = hooks
        try writeSettings(settings)
        Self.logger.info("Hooks installed for project at \(projectRoot.path, privacy: .public)")
    }

    /// Removes only Atelier's hooks, preserving user-defined hooks.
    public func uninstall() throws {
        guard var settings = readSettings() else { return }
        guard var hooks = settings["hooks"] as? [String: Any] else { return }

        for (event, entries) in hooks {
            guard var eventEntries = entries as? [[String: Any]] else { continue }
            eventEntries.removeAll { isAtelierManaged($0) }
            if eventEntries.isEmpty {
                hooks.removeValue(forKey: event)
            } else {
                hooks[event] = eventEntries
            }
        }

        if hooks.isEmpty {
            settings.removeValue(forKey: "hooks")
        } else {
            settings["hooks"] = hooks
        }

        if settings.isEmpty {
            try? FileManager.default.removeItem(at: settingsURL)
        } else {
            try writeSettings(settings)
        }
        Self.logger.info("Hooks uninstalled for project at \(projectRoot.path, privacy: .public)")
    }

    // MARK: - Hook Definitions

    func buildAtelierHooks() -> [String: Any] {
        let path = learningsPath

        // The re-inject command: reads learnings and wraps in <project-memory> tags.
        // Uses a shell script inline to handle the missing-file case gracefully.
        let reinjectCommand = """
        if [ -f '\(path)' ]; then \
        echo '<project-memory>'; \
        echo 'The following learnings are automatically managed by Atelier.'; \
        echo 'Do NOT read, edit, or write these files with tools.'; \
        echo ''; \
        cat '\(path)'; \
        echo '</project-memory>'; \
        fi
        """

        return [
            "SessionStart": [
                [
                    "matcher": "compact",
                    "hooks": [[
                        "type": "command",
                        "command": reinjectCommand,
                        "timeout": 5,
                        "statusMessage": "\(Self.statusMessagePrefix) Re-injecting project memory",
                    ] as [String: Any]],
                ] as [String: Any],
                [
                    "matcher": "startup",
                    "hooks": [[
                        "type": "command",
                        "command": reinjectCommand,
                        "timeout": 5,
                        "statusMessage": "\(Self.statusMessagePrefix) Loading project memory",
                    ] as [String: Any]],
                ] as [String: Any],
                [
                    "matcher": "resume",
                    "hooks": [[
                        "type": "command",
                        "command": reinjectCommand,
                        "timeout": 5,
                        "statusMessage": "\(Self.statusMessagePrefix) Loading project memory",
                    ] as [String: Any]],
                ] as [String: Any],
            ],
        ]
    }

    // MARK: - Settings File I/O

    private func readSettings() -> [String: Any]? {
        guard let data = try? Data(contentsOf: settingsURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return json
    }

    private func writeSettings(_ settings: [String: Any]) throws {
        let dir = settingsURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let data = try JSONSerialization.data(
            withJSONObject: settings,
            options: [.prettyPrinted, .sortedKeys]
        )
        try data.write(to: settingsURL, options: .atomic)
    }

    // MARK: - Identification

    /// Checks if a hook entry was created by Atelier.
    private func isAtelierManaged(_ entry: [String: Any]) -> Bool {
        guard let hooks = entry["hooks"] as? [[String: Any]] else { return false }
        return hooks.contains { hook in
            guard let message = hook["statusMessage"] as? String else { return false }
            return message.hasPrefix(Self.statusMessagePrefix)
        }
    }
}
