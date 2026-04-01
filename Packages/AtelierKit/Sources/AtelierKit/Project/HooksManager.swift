import Foundation
import os

/// Manages Atelier's hook registration in `.claude/settings.local.json`.
///
/// Hooks are the CLI's lifecycle event system. Atelier registers hooks to:
/// - Re-inject learnings after context compaction (`SessionStart[compact/startup/resume]`)
/// - Distill learnings when Claude finishes responding (`Stop`)
/// - Distill learnings before context compresses (`PreCompact`)
/// - Validate file tool paths against the project boundary (`PreToolUse`)
///
/// The manager merges Atelier's hooks with any user-defined hooks already in
/// the file, and can cleanly remove only Atelier's hooks on uninstall.
public struct HooksManager: Sendable {
    private static let logger = Logger(subsystem: "com.atelier.kit", category: "HooksManager")

    /// Marker to identify Atelier-managed hooks.
    static let statusMessagePrefix = "[Atelier]"

    /// Name of the bundled hooks helper binary in `Contents/Helpers/`.
    static let helperName = "atelier-hooks"

    /// The project root containing `.claude/`.
    public let projectRoot: URL

    /// Absolute path to the hooks helper binary, if found in the app bundle.
    let helperPath: String?

    public init(projectRoot: URL) {
        self.projectRoot = projectRoot
        self.helperPath = CLIEngine.bundledHelperPath(named: Self.helperName)
    }

    init(projectRoot: URL, helperPath: String?) {
        self.projectRoot = projectRoot
        self.helperPath = helperPath
    }

    /// Path to `.claude/settings.local.json` within the project.
    var settingsURL: URL {
        projectRoot
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("settings.local.json")
    }

    /// Path to `.atelier/memory/` within the project.
    private var memoryDirPath: String {
        projectRoot
            .appendingPathComponent(".atelier", isDirectory: true)
            .appendingPathComponent("memory", isDirectory: true)
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
        let distillCommand = distillCommandString()

        var hooks: [String: Any] = [
            "SessionStart": [
                [
                    "matcher": "compact",
                    "hooks": [[
                        "type": "command",
                        "command": reinjectCommandString(trigger: "compact"),
                        "timeout": 5,
                        "statusMessage": "\(Self.statusMessagePrefix) Re-injecting project memory",
                    ] as [String: Any]],
                ] as [String: Any],
                [
                    "matcher": "startup",
                    "hooks": [[
                        "type": "command",
                        "command": reinjectCommandString(trigger: "startup"),
                        "timeout": 5,
                        "statusMessage": "\(Self.statusMessagePrefix) Loading project memory",
                    ] as [String: Any]],
                ] as [String: Any],
                [
                    "matcher": "resume",
                    "hooks": [[
                        "type": "command",
                        "command": reinjectCommandString(trigger: "resume"),
                        "timeout": 5,
                        "statusMessage": "\(Self.statusMessagePrefix) Loading project memory",
                    ] as [String: Any]],
                ] as [String: Any],
            ],
        ]

        // Path guard hook validates file tool paths (defense-in-depth)
        if let guardCommand = pathGuardCommandString() {
            hooks["PreToolUse"] = [
                [
                    "matcher": "Read|Glob|Grep|Write|Edit|MultiEdit|NotebookEdit",
                    "hooks": [[
                        "type": "command",
                        "command": guardCommand,
                        "timeout": 5,
                        "statusMessage": "\(Self.statusMessagePrefix) Validating file access",
                    ] as [String: Any]],
                ] as [String: Any],
            ]
        }

        // Distillation hooks require the helper binary
        if distillCommand != nil {
            hooks["Stop"] = [
                [
                    "matcher": "",
                    "hooks": [[
                        "type": "command",
                        "command": distillCommand!,
                        "timeout": 300,
                        "async": true,
                        "statusMessage": "\(Self.statusMessagePrefix) Distilling learnings",
                    ] as [String: Any]],
                ] as [String: Any],
            ]

            hooks["PreCompact"] = [
                [
                    "matcher": "auto",
                    "hooks": [[
                        "type": "command",
                        "command": distillCommand!,
                        "timeout": 300,
                        "statusMessage": "\(Self.statusMessagePrefix) Saving learnings before compaction",
                    ] as [String: Any]],
                ] as [String: Any],
            ]
        }

        return hooks
    }

    /// Builds the reinject command string.
    ///
    /// - Parameter trigger: The SessionStart matcher (`compact`, `startup`, or `resume`).
    ///
    /// Prefers the bundled helper binary; falls back to inline shell that reads
    /// all `.md` files from the memory directory.
    func reinjectCommandString(trigger: String = "startup") -> String {
        if let helper = helperPath {
            return "'\(helper)' reinject \(trigger)"
        }

        let dir = memoryDirPath
        return """
        if [ -d '\(dir)' ]; then \
        files=$(find '\(dir)' -name '*.md' -type f 2>/dev/null | sort); \
        if [ -n "$files" ]; then \
        echo '<project-memory>'; \
        echo 'The following learnings are automatically managed by Atelier.'; \
        echo 'Do NOT read, edit, or write these files with tools.'; \
        echo ''; \
        for f in $files; do cat "$f"; echo ''; done; \
        echo '</project-memory>'; \
        fi; \
        fi
        """
    }

    /// Builds the distill command string, or nil if the helper binary is unavailable.
    func distillCommandString() -> String? {
        guard let helper = helperPath else { return nil }
        return "'\(helper)' distill"
    }

    /// Builds the path-guard command string, or nil if the helper binary is unavailable.
    func pathGuardCommandString() -> String? {
        guard let helper = helperPath else { return nil }
        return "'\(helper)' path-guard"
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
