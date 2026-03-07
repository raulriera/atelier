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

    private func readJSON(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        return try JSONSerialization.jsonObject(with: data) as! [String: Any]
    }

    // MARK: - Install

    @Test func installCreatesSettingsFile() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = HooksManager(projectRoot: root)
        try manager.install()

        #expect(FileManager.default.fileExists(atPath: manager.settingsURL.path))
    }

    @Test func installRegistersSessionStartHooks() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = HooksManager(projectRoot: root)
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

        let manager = HooksManager(projectRoot: root)
        try manager.install()
        try manager.install()

        let settings = try readJSON(at: manager.settingsURL)
        let hooks = settings["hooks"] as! [String: Any]
        let sessionStart = hooks["SessionStart"] as! [[String: Any]]

        // Should have exactly 3 entries (compact, startup, resume), not 6
        #expect(sessionStart.count == 3)
    }

    @Test func installPreservesUserHooks() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        // Write a user hook first
        let manager = HooksManager(projectRoot: root)
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

        // User hook + 3 Atelier hooks = 4 entries
        #expect(sessionStart.count == 4)

        // User hook still present
        let userEntry = sessionStart.first { entry in
            guard let entryHooks = entry["hooks"] as? [[String: Any]] else { return false }
            return entryHooks.contains { ($0["command"] as? String) == "echo user-hook" }
        }
        #expect(userEntry != nil)
    }

    @Test func installPreservesOtherSettings() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = HooksManager(projectRoot: root)
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

    // MARK: - Hook Content

    @Test func compactHookReInjectsLearnings() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = HooksManager(projectRoot: root)
        let hooks = manager.buildAtelierHooks()

        let sessionStart = hooks["SessionStart"] as! [[String: Any]]
        let compactEntry = sessionStart.first { ($0["matcher"] as? String) == "compact" }!
        let compactHooks = compactEntry["hooks"] as! [[String: Any]]
        let command = compactHooks[0]["command"] as! String

        #expect(command.contains("learnings.md"))
        #expect(command.contains("<project-memory>"))
        #expect(command.contains("</project-memory>"))
    }

    @Test func hooksHaveAtelierStatusMessage() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = HooksManager(projectRoot: root)
        let hooks = manager.buildAtelierHooks()

        let sessionStart = hooks["SessionStart"] as! [[String: Any]]
        for entry in sessionStart {
            let entryHooks = entry["hooks"] as! [[String: Any]]
            for hook in entryHooks {
                let message = hook["statusMessage"] as! String
                #expect(message.hasPrefix(HooksManager.statusMessagePrefix))
            }
        }
    }

    @Test func hooksHaveShortTimeout() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = HooksManager(projectRoot: root)
        let hooks = manager.buildAtelierHooks()

        let sessionStart = hooks["SessionStart"] as! [[String: Any]]
        for entry in sessionStart {
            let entryHooks = entry["hooks"] as! [[String: Any]]
            for hook in entryHooks {
                let timeout = hook["timeout"] as! Int
                #expect(timeout <= 10)
            }
        }
    }

    // MARK: - Shell Command Behavior

    @Test func reinjectCommandOutputsLearningsWhenFileExists() async throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        // Create a learnings file
        let memoryDir = root
            .appendingPathComponent(".atelier", isDirectory: true)
            .appendingPathComponent("memory", isDirectory: true)
        try FileManager.default.createDirectory(at: memoryDir, withIntermediateDirectories: true)
        try "## Preferences\n- Use tabs".write(
            to: memoryDir.appendingPathComponent("learnings.md"),
            atomically: true, encoding: .utf8
        )

        let manager = HooksManager(projectRoot: root)
        let hooks = manager.buildAtelierHooks()
        let sessionStart = hooks["SessionStart"] as! [[String: Any]]
        let compactEntry = sessionStart.first { ($0["matcher"] as? String) == "compact" }!
        let command = (compactEntry["hooks"] as! [[String: Any]])[0]["command"] as! String

        // Run the actual shell command
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

        let manager = HooksManager(projectRoot: root)
        let hooks = manager.buildAtelierHooks()
        let sessionStart = hooks["SessionStart"] as! [[String: Any]]
        let compactEntry = sessionStart.first { ($0["matcher"] as? String) == "compact" }!
        let command = (compactEntry["hooks"] as! [[String: Any]])[0]["command"] as! String

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

        let manager = HooksManager(projectRoot: root)
        try manager.install()
        try manager.uninstall()

        // File should be removed since no other settings remain
        #expect(!FileManager.default.fileExists(atPath: manager.settingsURL.path))
    }

    @Test func uninstallPreservesUserHooks() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = HooksManager(projectRoot: root)
        let claudeDir = root.appendingPathComponent(".claude", isDirectory: true)
        try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)

        // Write user hook + install Atelier hooks
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

        // Atelier's SessionStart hooks should be gone
        #expect(hooks["SessionStart"] == nil)

        // User's Stop hook should remain
        let stopHooks = hooks["Stop"] as! [[String: Any]]
        #expect(stopHooks.count == 1)
    }

    @Test func uninstallIsIdempotent() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = HooksManager(projectRoot: root)
        try manager.install()
        try manager.uninstall()
        try manager.uninstall() // Should not throw
    }

    @Test func uninstallWithNoFileDoesNotThrow() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = HooksManager(projectRoot: root)
        try manager.uninstall() // No file exists — should be a no-op
    }
}
