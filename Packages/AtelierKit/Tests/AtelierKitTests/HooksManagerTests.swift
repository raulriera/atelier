import Foundation
import Testing
@testable import AtelierKit

@Suite("HooksManager")
struct HooksManagerTests {

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("atelier-hooks-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Creates a manager without a helper binary (shell fallback for reinject, no distill hooks).
    private func makeManager(root: URL) -> HooksManager {
        HooksManager(projectRoot: root, helperPath: nil)
    }

    /// Creates a manager with a fake helper path (enables distill hooks).
    private func makeManagerWithHelper(root: URL) -> HooksManager {
        HooksManager(projectRoot: root, helperPath: "/fake/atelier-hooks")
    }

    private func readJSON(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    // MARK: - Install

    @Test func installCreatesSettingsFile() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = makeManager(root: root)
        try manager.install()

        #expect(FileManager.default.fileExists(atPath: manager.settingsURL.path))
    }

    @Test func installRegistersSessionStartHooks() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = makeManager(root: root)
        try manager.install()

        let settings = try readJSON(at: manager.settingsURL)
        let hooks = settings["hooks"] as! [String: Any]
        let sessionStart = hooks["SessionStart"] as! [[String: Any]]

        let matchers = sessionStart.map { $0["matcher"] as! String }
        #expect(matchers.contains("compact"))
        #expect(matchers.contains("startup"))
        #expect(matchers.contains("resume"))
    }

    @Test func installIsIdempotent() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = makeManager(root: root)
        try manager.install()
        try manager.install()

        let settings = try readJSON(at: manager.settingsURL)
        let hooks = settings["hooks"] as! [String: Any]
        let sessionStart = hooks["SessionStart"] as! [[String: Any]]

        #expect(sessionStart.count == 3)
    }

    @Test func installPreservesUserHooks() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = makeManager(root: root)
        let claudeDir = root.appendingPathComponent(".claude", isDirectory: true)
        try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)

        let userSettings: [String: Any] = [
            "hooks": [
                "SessionStart": [
                    [
                        "matcher": "startup",
                        "hooks": [["type": "command", "command": "echo user-hook"]],
                    ] as [String: Any]
                ]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: userSettings, options: .prettyPrinted)
        try data.write(to: manager.settingsURL)

        try manager.install()

        let settings = try readJSON(at: manager.settingsURL)
        let hooks = settings["hooks"] as! [String: Any]
        let sessionStart = hooks["SessionStart"] as! [[String: Any]]

        // User hook + 3 Atelier hooks = 4
        #expect(sessionStart.count == 4)

        let userEntry = sessionStart.first { entry in
            guard let entryHooks = entry["hooks"] as? [[String: Any]] else { return false }
            return entryHooks.contains { ($0["command"] as? String) == "echo user-hook" }
        }
        #expect(userEntry != nil)
    }

    @Test func installPreservesOtherSettings() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = makeManager(root: root)
        let claudeDir = root.appendingPathComponent(".claude", isDirectory: true)
        try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)

        let existing: [String: Any] = ["permissions": ["allow": ["Read", "Glob"]]]
        let data = try JSONSerialization.data(withJSONObject: existing)
        try data.write(to: manager.settingsURL)

        try manager.install()

        let settings = try readJSON(at: manager.settingsURL)
        #expect(settings["permissions"] != nil)
        #expect(settings["hooks"] != nil)
    }

    // MARK: - Hook Content (without helper binary)

    @Test func reinjectFallsBackToShellWithoutHelper() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = makeManager(root: root)
        let command = manager.reinjectCommandString()

        #expect(command.contains("cat"))
        #expect(command.contains("*.md"))
        #expect(command.contains("<project-memory>"))
    }

    @Test func distillReturnsNilWithoutHelper() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = makeManager(root: root)
        #expect(manager.distillCommandString() == nil)
    }

    @Test func noDistillHooksWithoutHelper() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = makeManager(root: root)
        let hooks = manager.buildAtelierHooks()

        #expect(hooks["Stop"] == nil)
        #expect(hooks["PreCompact"] == nil)
    }

    // MARK: - Hook Content (with helper binary)

    @Test func reinjectUsesHelperWhenAvailable() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = makeManagerWithHelper(root: root)
        let command = manager.reinjectCommandString()

        #expect(command.contains("atelier-hooks"))
        #expect(command.contains("reinject"))
    }

    @Test func distillUsesHelper() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = makeManagerWithHelper(root: root)
        let command = manager.distillCommandString()

        #expect(command != nil)
        #expect(command!.contains("atelier-hooks"))
        #expect(command!.contains("distill"))
    }

    @Test func stopHookRegisteredWithHelper() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = makeManagerWithHelper(root: root)
        try manager.install()

        let settings = try readJSON(at: manager.settingsURL)
        let hooks = settings["hooks"] as! [String: Any]
        let stop = hooks["Stop"] as! [[String: Any]]

        #expect(stop.count == 1)
        let stopHooks = stop[0]["hooks"] as! [[String: Any]]
        #expect((stopHooks[0]["async"] as? Bool) == true)
        #expect((stopHooks[0]["command"] as? String)?.contains("distill") == true)
    }

    @Test func preCompactHookRegisteredWithHelper() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = makeManagerWithHelper(root: root)
        try manager.install()

        let settings = try readJSON(at: manager.settingsURL)
        let hooks = settings["hooks"] as! [String: Any]
        let preCompact = hooks["PreCompact"] as! [[String: Any]]

        #expect(preCompact.count == 1)
        #expect((preCompact[0]["matcher"] as? String) == "auto")
    }

    @Test func preToolUsePathGuardRegisteredWithHelper() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = makeManagerWithHelper(root: root)
        try manager.install()

        let settings = try readJSON(at: manager.settingsURL)
        let hooks = try #require(settings["hooks"] as? [String: Any])
        let preToolUse = try #require(hooks["PreToolUse"] as? [[String: Any]])

        #expect(preToolUse.count == 1)
        #expect((preToolUse[0]["matcher"] as? String) == "Read|Glob|Grep|Write|Edit|MultiEdit|NotebookEdit")
        let preHooks = try #require(preToolUse[0]["hooks"] as? [[String: Any]])
        #expect((preHooks[0]["command"] as? String)?.contains("path-guard") == true)
    }

    @Test func pathGuardReturnsNilWithoutHelper() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = makeManager(root: root)
        #expect(manager.pathGuardCommandString() == nil)
    }

    @Test func noPreToolUseHookWithoutHelper() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = makeManager(root: root)
        let hooks = manager.buildAtelierHooks()
        #expect(hooks["PreToolUse"] == nil)
    }

    @Test func stopHookIsAsync() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = makeManagerWithHelper(root: root)
        let hooks = manager.buildAtelierHooks()
        let stop = hooks["Stop"] as! [[String: Any]]
        let stopHooks = stop[0]["hooks"] as! [[String: Any]]

        #expect((stopHooks[0]["async"] as? Bool) == true)
    }

    @Test func preCompactHookIsNotAsync() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = makeManagerWithHelper(root: root)
        let hooks = manager.buildAtelierHooks()
        let preCompact = hooks["PreCompact"] as! [[String: Any]]
        let preCompactHooks = preCompact[0]["hooks"] as! [[String: Any]]

        // PreCompact must be synchronous — learnings need to be saved before compaction
        #expect(preCompactHooks[0]["async"] == nil)
    }

    @Test func installWithHelperIsIdempotent() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = makeManagerWithHelper(root: root)
        try manager.install()
        try manager.install()

        let settings = try readJSON(at: manager.settingsURL)
        let hooks = settings["hooks"] as! [String: Any]
        let sessionStart = hooks["SessionStart"] as! [[String: Any]]
        let stop = hooks["Stop"] as! [[String: Any]]
        let preCompact = hooks["PreCompact"] as! [[String: Any]]
        let preToolUse = hooks["PreToolUse"] as! [[String: Any]]

        #expect(sessionStart.count == 3)
        #expect(stop.count == 1)
        #expect(preCompact.count == 1)
        #expect(preToolUse.count == 1)
    }

    // MARK: - Status Messages

    @Test func allHooksHaveAtelierStatusMessage() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = makeManagerWithHelper(root: root)
        let hooks = manager.buildAtelierHooks()

        for (_, entries) in hooks {
            let eventEntries = entries as! [[String: Any]]
            for entry in eventEntries {
                let entryHooks = entry["hooks"] as! [[String: Any]]
                for hook in entryHooks {
                    let message = hook["statusMessage"] as! String
                    #expect(message.hasPrefix(HooksManager.statusMessagePrefix))
                }
            }
        }
    }

    // MARK: - User Hook Coexistence

    @Test func userCompactHookCoexistsWithAtelier() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = makeManagerWithHelper(root: root)
        let claudeDir = root.appendingPathComponent(".claude", isDirectory: true)
        try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)

        // User has their own compact hook
        let userSettings: [String: Any] = [
            "hooks": [
                "SessionStart": [
                    [
                        "matcher": "compact",
                        "hooks": [["type": "command", "command": "echo user-compact-hook"]],
                    ] as [String: Any]
                ]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: userSettings, options: .prettyPrinted)
        try data.write(to: manager.settingsURL)

        try manager.install()

        let settings = try readJSON(at: manager.settingsURL)
        let hooks = settings["hooks"] as! [String: Any]
        let sessionStart = hooks["SessionStart"] as! [[String: Any]]

        // Both the user's compact hook and Atelier's compact hook should exist
        let compactEntries = sessionStart.filter { ($0["matcher"] as? String) == "compact" }
        #expect(compactEntries.count == 2)

        // User hook is still there
        let userEntry = compactEntries.first { entry in
            let entryHooks = entry["hooks"] as! [[String: Any]]
            return entryHooks.contains { ($0["command"] as? String) == "echo user-compact-hook" }
        }
        #expect(userEntry != nil)
    }

    @Test func userStopHookCoexistsWithAtelier() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = makeManagerWithHelper(root: root)
        let claudeDir = root.appendingPathComponent(".claude", isDirectory: true)
        try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)

        // User has their own Stop hook
        let userSettings: [String: Any] = [
            "hooks": [
                "Stop": [
                    [
                        "matcher": "",
                        "hooks": [["type": "command", "command": "echo user-stop"]],
                    ] as [String: Any]
                ]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: userSettings, options: .prettyPrinted)
        try data.write(to: manager.settingsURL)

        try manager.install()

        let settings = try readJSON(at: manager.settingsURL)
        let hooks = settings["hooks"] as! [String: Any]
        let stop = hooks["Stop"] as! [[String: Any]]

        // User's Stop + Atelier's Stop = 2
        #expect(stop.count == 2)

        let userEntry = stop.first { entry in
            let entryHooks = entry["hooks"] as! [[String: Any]]
            return entryHooks.contains { ($0["command"] as? String) == "echo user-stop" }
        }
        #expect(userEntry != nil)

        let atelierEntry = stop.first { entry in
            let entryHooks = entry["hooks"] as! [[String: Any]]
            return entryHooks.contains { ($0["statusMessage"] as? String)?.hasPrefix("[Atelier]") == true }
        }
        #expect(atelierEntry != nil)
    }

    @Test func userPreCompactHookCoexistsWithAtelier() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = makeManagerWithHelper(root: root)
        let claudeDir = root.appendingPathComponent(".claude", isDirectory: true)
        try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)

        let userSettings: [String: Any] = [
            "hooks": [
                "PreCompact": [
                    [
                        "matcher": "auto",
                        "hooks": [["type": "command", "command": "echo user-precompact"]],
                    ] as [String: Any]
                ]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: userSettings, options: .prettyPrinted)
        try data.write(to: manager.settingsURL)

        try manager.install()

        let settings = try readJSON(at: manager.settingsURL)
        let hooks = settings["hooks"] as! [String: Any]
        let preCompact = hooks["PreCompact"] as! [[String: Any]]

        #expect(preCompact.count == 2)

        let userEntry = preCompact.first { entry in
            let entryHooks = entry["hooks"] as! [[String: Any]]
            return entryHooks.contains { ($0["command"] as? String) == "echo user-precompact" }
        }
        #expect(userEntry != nil)
    }

    @Test func reinstallDoesNotDuplicateButPreservesUserHooks() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = makeManagerWithHelper(root: root)
        let claudeDir = root.appendingPathComponent(".claude", isDirectory: true)
        try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)

        // User has hooks on multiple events
        let userSettings: [String: Any] = [
            "hooks": [
                "SessionStart": [
                    [
                        "matcher": "compact",
                        "hooks": [["type": "command", "command": "echo user-compact"]],
                    ] as [String: Any]
                ],
                "Stop": [
                    [
                        "matcher": "",
                        "hooks": [["type": "command", "command": "echo user-stop"]],
                    ] as [String: Any]
                ],
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: userSettings, options: .prettyPrinted)
        try data.write(to: manager.settingsURL)

        // Install twice
        try manager.install()
        try manager.install()

        let settings = try readJSON(at: manager.settingsURL)
        let hooks = settings["hooks"] as! [String: Any]

        let sessionStart = hooks["SessionStart"] as! [[String: Any]]
        let stop = hooks["Stop"] as! [[String: Any]]

        // 1 user compact + 3 Atelier SessionStart = 4
        #expect(sessionStart.count == 4)
        // 1 user stop + 1 Atelier stop = 2
        #expect(stop.count == 2)
    }

    @Test func uninstallRemovesAtelierButKeepsUserOnSameEvent() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = makeManagerWithHelper(root: root)
        let claudeDir = root.appendingPathComponent(".claude", isDirectory: true)
        try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)

        // User has compact hook + Atelier installs its own
        let userSettings: [String: Any] = [
            "hooks": [
                "SessionStart": [
                    [
                        "matcher": "compact",
                        "hooks": [["type": "command", "command": "echo user-compact"]],
                    ] as [String: Any]
                ]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: userSettings, options: .prettyPrinted)
        try data.write(to: manager.settingsURL)

        try manager.install()
        try manager.uninstall()

        let settings = try readJSON(at: manager.settingsURL)
        let hooks = settings["hooks"] as! [String: Any]
        let sessionStart = hooks["SessionStart"] as! [[String: Any]]

        // Only user's compact hook remains
        #expect(sessionStart.count == 1)
        let entryHooks = sessionStart[0]["hooks"] as! [[String: Any]]
        #expect((entryHooks[0]["command"] as? String) == "echo user-compact")

        // Atelier events fully removed
        #expect(hooks["Stop"] == nil)
        #expect(hooks["PreCompact"] == nil)
        #expect(hooks["PreToolUse"] == nil)
    }

    @Test func userHooksWithStatusMessageNotMistakenForAtelier() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = makeManager(root: root)
        let claudeDir = root.appendingPathComponent(".claude", isDirectory: true)
        try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)

        // User hook has a statusMessage but NOT with [Atelier] prefix
        let userSettings: [String: Any] = [
            "hooks": [
                "SessionStart": [
                    [
                        "matcher": "startup",
                        "hooks": [[
                            "type": "command",
                            "command": "echo my-tool",
                            "statusMessage": "[MyTool] Loading context",
                        ] as [String: Any]],
                    ] as [String: Any]
                ]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: userSettings, options: .prettyPrinted)
        try data.write(to: manager.settingsURL)

        try manager.install()

        let settings = try readJSON(at: manager.settingsURL)
        let hooks = settings["hooks"] as! [String: Any]
        let sessionStart = hooks["SessionStart"] as! [[String: Any]]

        // User hook with [MyTool] prefix + 3 Atelier hooks = 4
        #expect(sessionStart.count == 4)

        // Uninstall should only remove [Atelier] hooks
        try manager.uninstall()

        let afterSettings = try readJSON(at: manager.settingsURL)
        let afterHooks = afterSettings["hooks"] as! [String: Any]
        let afterSessionStart = afterHooks["SessionStart"] as! [[String: Any]]
        #expect(afterSessionStart.count == 1)

        let remaining = afterSessionStart[0]["hooks"] as! [[String: Any]]
        #expect((remaining[0]["statusMessage"] as? String) == "[MyTool] Loading context")
    }

    // MARK: - Shell Command Behavior

    @Test func reinjectCommandOutputsMultipleMemoryFiles() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let memoryDir = root
            .appendingPathComponent(".atelier", isDirectory: true)
            .appendingPathComponent("memory", isDirectory: true)
        try FileManager.default.createDirectory(at: memoryDir, withIntermediateDirectories: true)
        try "## Preferences\n- Use tabs".write(
            to: memoryDir.appendingPathComponent("preferences.md"),
            atomically: true, encoding: .utf8
        )
        try "## Decisions\n- Chose SwiftUI".write(
            to: memoryDir.appendingPathComponent("decisions.md"),
            atomically: true, encoding: .utf8
        )

        let manager = makeManager(root: root)
        let command = manager.reinjectCommandString()

        let output = try runShellCommand(command, cwd: root)

        #expect(output.contains("<project-memory>"))
        #expect(output.contains("## Preferences"))
        #expect(output.contains("- Use tabs"))
        #expect(output.contains("## Decisions"))
        #expect(output.contains("- Chose SwiftUI"))
        #expect(output.contains("</project-memory>"))
    }

    @Test func reinjectCommandOutputsSingleFile() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let memoryDir = root
            .appendingPathComponent(".atelier", isDirectory: true)
            .appendingPathComponent("memory", isDirectory: true)
        try FileManager.default.createDirectory(at: memoryDir, withIntermediateDirectories: true)
        try "## Patterns\n- Files organized by client".write(
            to: memoryDir.appendingPathComponent("patterns.md"),
            atomically: true, encoding: .utf8
        )

        let manager = makeManager(root: root)
        let command = manager.reinjectCommandString()

        let output = try runShellCommand(command, cwd: root)

        #expect(output.contains("<project-memory>"))
        #expect(output.contains("## Patterns"))
        #expect(output.contains("</project-memory>"))
    }

    @Test func reinjectCommandProducesNoOutputWhenNoFiles() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = makeManager(root: root)
        let command = manager.reinjectCommandString()

        let output = try runShellCommand(command, cwd: root)

        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @Test func reinjectCommandProducesNoOutputForEmptyDirectory() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let memoryDir = root
            .appendingPathComponent(".atelier", isDirectory: true)
            .appendingPathComponent("memory", isDirectory: true)
        try FileManager.default.createDirectory(at: memoryDir, withIntermediateDirectories: true)

        let manager = makeManager(root: root)
        let command = manager.reinjectCommandString()

        let output = try runShellCommand(command, cwd: root)

        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    /// Runs a shell command and returns its stdout.
    private func runShellCommand(_ command: String, cwd: URL) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = cwd
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()
        return String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }

    // MARK: - Uninstall

    @Test func uninstallRemovesAtelierHooks() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = makeManagerWithHelper(root: root)
        try manager.install()
        try manager.uninstall()

        #expect(!FileManager.default.fileExists(atPath: manager.settingsURL.path))
    }

    @Test func uninstallPreservesUserHooks() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = makeManagerWithHelper(root: root)
        let claudeDir = root.appendingPathComponent(".claude", isDirectory: true)
        try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)

        let userSettings: [String: Any] = [
            "hooks": [
                "Stop": [
                    [
                        "matcher": "",
                        "hooks": [["type": "command", "command": "echo user-stop"]],
                    ] as [String: Any]
                ]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: userSettings, options: .prettyPrinted)
        try data.write(to: manager.settingsURL)

        try manager.install()
        try manager.uninstall()

        let settings = try readJSON(at: manager.settingsURL)
        let hooks = settings["hooks"] as! [String: Any]

        #expect(hooks["SessionStart"] == nil)
        #expect(hooks["Stop"] != nil)

        let stopHooks = hooks["Stop"] as! [[String: Any]]
        #expect(stopHooks.count == 1)
    }

    @Test func uninstallIsIdempotent() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = makeManager(root: root)
        try manager.install()
        try manager.uninstall()
        try manager.uninstall()
    }

    @Test func uninstallWithNoFileDoesNotThrow() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = makeManager(root: root)
        try manager.uninstall()
    }
}
