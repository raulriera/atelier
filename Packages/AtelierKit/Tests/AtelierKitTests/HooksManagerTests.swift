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
        #expect(command.contains("learnings.md"))
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

        #expect(sessionStart.count == 3)
        #expect(stop.count == 1)
        #expect(preCompact.count == 1)
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

    // MARK: - Shell Command Behavior

    @Test func reinjectCommandOutputsLearningsWhenFileExists() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let memoryDir = root
            .appendingPathComponent(".atelier", isDirectory: true)
            .appendingPathComponent("memory", isDirectory: true)
        try FileManager.default.createDirectory(at: memoryDir, withIntermediateDirectories: true)
        try "## Preferences\n- Use tabs".write(
            to: memoryDir.appendingPathComponent("learnings.md"),
            atomically: true, encoding: .utf8
        )

        let manager = makeManager(root: root)
        let command = manager.reinjectCommandString()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = root
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()

        let output = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        #expect(output.contains("<project-memory>"))
        #expect(output.contains("## Preferences"))
        #expect(output.contains("- Use tabs"))
        #expect(output.contains("</project-memory>"))
        #expect(process.terminationStatus == 0)
    }

    @Test func reinjectCommandProducesNoOutputWhenNoFile() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = makeManager(root: root)
        let command = manager.reinjectCommandString()

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = root
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        try process.run()
        process.waitUntilExit()

        let output = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        #expect(output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(process.terminationStatus == 0)
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
