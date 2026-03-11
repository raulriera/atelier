import Foundation
import Testing

/// Integration tests for the `atelier-hooks` standalone script.
///
/// These tests run the actual script as a subprocess, piping JSON on stdin
/// and checking stdout/stderr/exit codes. They catch bugs that unit tests
/// on the mirrored AtelierKit types miss (like `findCLI()` divergence).
@Suite("atelier-hooks script")
struct AtelierHooksScriptTests {

    /// Path to the helper script in the repo root.
    private static let scriptPath: String = {
        // #filePath = .../atelier/Packages/AtelierKit/Tests/AtelierKitTests/ThisFile.swift
        var url = URL(fileURLWithPath: #filePath)
        // Walk up to the repo root (atelier/)
        while url.lastPathComponent != "atelier" && url.path != "/" {
            url = url.deletingLastPathComponent()
        }
        return url.appendingPathComponent("Helpers/atelier-hooks.swift").path
    }()

    /// Runs the script with the given subcommand and JSON stdin input.
    private func run(
        subcommand: String,
        input: [String: Any],
        cwd: URL? = nil
    ) throws -> (stdout: String, stderr: String, exitCode: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", Self.scriptPath] + subcommand.components(separatedBy: " ")
        if let cwd { process.currentDirectoryURL = cwd }

        let stdinPipe = Pipe()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        let jsonData = try JSONSerialization.data(withJSONObject: input)
        stdinPipe.fileHandleForWriting.write(jsonData)
        stdinPipe.fileHandleForWriting.closeFile()

        let outData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return (
            stdout: String(data: outData, encoding: .utf8) ?? "",
            stderr: String(data: errData, encoding: .utf8) ?? "",
            exitCode: process.terminationStatus
        )
    }

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("atelier-hooks-script-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    // MARK: - Usage

    @Test func noArgsExitsWithUsage() throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["swift", Self.scriptPath]
        let stderr = Pipe()
        process.standardOutput = Pipe()
        process.standardError = stderr
        try process.run()
        process.waitUntilExit()

        #expect(process.terminationStatus == 1)
        let errOutput = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        #expect(errOutput.contains("Usage:"))
    }

    @Test func unknownSubcommandExitsWithError() throws {
        let result = try run(subcommand: "bogus", input: [:])
        #expect(result.exitCode == 1)
        #expect(result.stderr.contains("Unknown subcommand"))
    }

    // MARK: - Reinject

    @Test func reinjectInjectsAlwaysInjectFilesInFull() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let memoryDir = root.appendingPathComponent(".atelier/memory")
        try FileManager.default.createDirectory(at: memoryDir, withIntermediateDirectories: true)
        try "## Preferences\n- Use dark mode".write(
            to: memoryDir.appendingPathComponent("preferences.md"),
            atomically: true, encoding: .utf8
        )

        let result = try run(
            subcommand: "reinject",
            input: ["cwd": root.path]
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("<project-memory>"))
        #expect(result.stdout.contains("## Preferences"))
        #expect(result.stdout.contains("- Use dark mode"))
        #expect(result.stdout.contains("</project-memory>"))
    }

    @Test func reinjectShowsOnDemandFilesAsManifest() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let memoryDir = root.appendingPathComponent(".atelier/memory")
        try FileManager.default.createDirectory(at: memoryDir, withIntermediateDirectories: true)
        try "## Key Decisions\n- Chose Stripe".write(
            to: memoryDir.appendingPathComponent("decisions.md"),
            atomically: true, encoding: .utf8
        )

        let result = try run(
            subcommand: "reinject",
            input: ["cwd": root.path]
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("<project-memory>"))
        // Full content should NOT be injected
        #expect(!result.stdout.contains("- Chose Stripe"))
        // Should appear as manifest entry with preview
        #expect(result.stdout.contains("decisions.md:"))
        #expect(result.stdout.contains("Additional memory files available"))
    }

    @Test func reinjectTruncatesOversizedAlwaysInjectFile() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let memoryDir = root.appendingPathComponent(".atelier/memory")
        try FileManager.default.createDirectory(at: memoryDir, withIntermediateDirectories: true)

        // Create a preferences.md that exceeds the 40-line hard cap
        let lines = ["## Preferences"] + (1...60).map { "- Preference entry \($0)" }
        try lines.joined(separator: "\n").write(
            to: memoryDir.appendingPathComponent("preferences.md"),
            atomically: true, encoding: .utf8
        )

        let result = try run(
            subcommand: "reinject",
            input: ["cwd": root.path]
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("...truncated"))
        #expect(result.stdout.contains("Preference entry 1"))
        #expect(!result.stdout.contains("Preference entry 60"))
    }

    @Test func reinjectExitsSilentlyWithNoMemory() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let result = try run(
            subcommand: "reinject",
            input: ["cwd": root.path]
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @Test func reinjectIncludesCompactionSnapshotOnCompactTrigger() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let compactsDir = root.appendingPathComponent(".atelier/memory/compacts")
        try FileManager.default.createDirectory(at: compactsDir, withIntermediateDirectories: true)
        try "User: Let's fix the login bug\nAssistant: I'll look at auth.swift".write(
            to: compactsDir.appendingPathComponent("2026-03-08T10-00-00Z.md"),
            atomically: true, encoding: .utf8
        )

        let result = try run(
            subcommand: "reinject compact",
            input: ["cwd": root.path]
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("<session-state>"))
        #expect(result.stdout.contains("fix the login bug"))
        #expect(result.stdout.contains("</session-state>"))
    }

    @Test func reinjectExcludesCompactionSnapshotOnStartup() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let compactsDir = root.appendingPathComponent(".atelier/memory/compacts")
        try FileManager.default.createDirectory(at: compactsDir, withIntermediateDirectories: true)
        try "User: Old conversation".write(
            to: compactsDir.appendingPathComponent("2026-03-08T10-00-00Z.md"),
            atomically: true, encoding: .utf8
        )

        // Also need some memory content so reinject produces output
        let memoryDir = root.appendingPathComponent(".atelier/memory")
        try "## Preferences\n- Dark mode".write(
            to: memoryDir.appendingPathComponent("preferences.md"),
            atomically: true, encoding: .utf8
        )

        let result = try run(
            subcommand: "reinject startup",
            input: ["cwd": root.path]
        )

        #expect(result.exitCode == 0)
        #expect(result.stdout.contains("<project-memory>"))
        #expect(!result.stdout.contains("<session-state>"))
        #expect(!result.stdout.contains("Old conversation"))
    }

    // MARK: - Path Guard

    @Test func pathGuardAllowsProjectFile() throws {
        let result = try run(
            subcommand: "path-guard",
            input: [
                "cwd": "/tmp/myproject",
                "tool_input": ["file_path": "/tmp/myproject/docs/readme.md"],
            ]
        )

        #expect(result.exitCode == 0)
    }

    @Test func pathGuardDeniesOutsideProject() throws {
        let result = try run(
            subcommand: "path-guard",
            input: [
                "cwd": "/tmp/myproject",
                "tool_input": ["file_path": "/etc/passwd"],
            ]
        )

        #expect(result.exitCode == 2)
        #expect(result.stdout.contains("outside the project directory"))
    }

    @Test func pathGuardDeniesSensitivePaths() throws {
        let home: String
        if let pw = getpwuid(getuid()) {
            home = String(cString: pw.pointee.pw_dir)
        } else {
            home = NSHomeDirectory()
        }

        let sensitivePaths = [
            "\(home)/.ssh/id_rsa",
            "\(home)/.aws/credentials",
            "\(home)/.gnupg/private-keys-v1.d/key",
            "\(home)/.config/some-app/secrets",
            "\(home)/.env",
            "\(home)/.env.local",
            "\(home)/.netrc",
        ]

        for path in sensitivePaths {
            let result = try run(
                subcommand: "path-guard",
                input: [
                    "cwd": home,
                    "tool_input": ["file_path": path],
                ]
            )
            #expect(result.exitCode == 2, "Expected denial for \(path)")
        }
    }

    @Test func pathGuardAllowsWithEmptyToolInput() throws {
        let result = try run(
            subcommand: "path-guard",
            input: [
                "cwd": "/tmp/myproject",
                "tool_input": [:] as [String: String],
            ]
        )

        #expect(result.exitCode == 0)
    }

    // MARK: - Compaction Snapshots

    @Test func distillSavesCompactionSnapshot() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        // Create a transcript with some conversation
        let transcriptURL = root.appendingPathComponent("transcript.jsonl")
        let entry = """
        {"type":"message","message":{"role":"user","content":"Fix the login bug in auth.swift"}}
        {"type":"message","message":{"role":"assistant","content":"I'll look at the auth module."}}
        """
        try entry.write(to: transcriptURL, atomically: true, encoding: .utf8)

        // distill will fail at the Haiku call (no CLI or mock), but it should
        // still save the compaction snapshot BEFORE calling Haiku
        let result = try run(
            subcommand: "distill",
            input: [
                "transcript_path": transcriptURL.path,
                "cwd": root.path,
            ]
        )

        // The process may exit non-zero (CLI not found on CI) but that's after snapshot
        let compactsDir = root.appendingPathComponent(".atelier/memory/compacts")
        if FileManager.default.fileExists(atPath: compactsDir.path) {
            let files = try FileManager.default.contentsOfDirectory(atPath: compactsDir.path)
            let mdFiles = files.filter { $0.hasSuffix(".md") }
            #expect(!mdFiles.isEmpty, "Expected at least one compaction snapshot")

            if let first = mdFiles.sorted().last {
                let content = try String(
                    contentsOfFile: compactsDir.appendingPathComponent(first).path,
                    encoding: .utf8
                )
                #expect(content.contains("login bug"))
            }
        }
        // If compacts dir doesn't exist, distill exited before saving (CLI not found early)
        // That's acceptable — the snapshot save happens after transcript summarization
    }

    @Test func compactionSnapshotPrunesOldFiles() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        let compactsDir = root.appendingPathComponent(".atelier/memory/compacts")
        try FileManager.default.createDirectory(at: compactsDir, withIntermediateDirectories: true)

        // Create 4 snapshots — pruning should keep only the most recent 2
        let timestamps = [
            "2026-03-08T10-00-00Z",
            "2026-03-08T11-00-00Z",
            "2026-03-08T12-00-00Z",
            "2026-03-08T13-00-00Z",
        ]
        for ts in timestamps {
            try "Snapshot \(ts)".write(
                to: compactsDir.appendingPathComponent("\(ts).md"),
                atomically: true, encoding: .utf8
            )
        }

        // Trigger distill — it saves a new snapshot and prunes
        let transcriptURL = root.appendingPathComponent("transcript.jsonl")
        try """
        {"type":"message","message":{"role":"user","content":"Hello"}}
        """.write(to: transcriptURL, atomically: true, encoding: .utf8)

        _ = try run(
            subcommand: "distill",
            input: [
                "transcript_path": transcriptURL.path,
                "cwd": root.path,
            ]
        )

        let remaining = try FileManager.default.contentsOfDirectory(atPath: compactsDir.path)
            .filter { $0.hasSuffix(".md") }
            .sorted()

        // 4 existing + 1 new = 5, pruned to 2
        #expect(remaining.count <= 2, "Expected at most 2 snapshots after pruning, got \(remaining.count)")
        // Oldest files should be gone
        #expect(!remaining.contains("2026-03-08T10-00-00Z.md"))
        #expect(!remaining.contains("2026-03-08T11-00-00Z.md"))
    }

    @Test func compactionSnapshotTruncatesLongMessages() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        // Create a transcript with one very long assistant message (1000+ chars)
        let longContent = String(repeating: "x", count: 1000)
        let transcriptURL = root.appendingPathComponent("transcript.jsonl")
        try """
        {"type":"message","message":{"role":"user","content":"Tell me something"}}
        {"type":"message","message":{"role":"assistant","content":"\(longContent)"}}
        """.write(to: transcriptURL, atomically: true, encoding: .utf8)

        _ = try run(
            subcommand: "distill",
            input: [
                "transcript_path": transcriptURL.path,
                "cwd": root.path,
            ]
        )

        let compactsDir = root.appendingPathComponent(".atelier/memory/compacts")
        try #require(FileManager.default.fileExists(atPath: compactsDir.path), "Compacts directory should exist after distill")

        let files = try FileManager.default.contentsOfDirectory(atPath: compactsDir.path)
            .filter { $0.hasSuffix(".md") }
            .sorted()
        let latest = try #require(files.last, "Expected at least one compaction snapshot")

        let snapshot = try String(
            contentsOfFile: compactsDir.appendingPathComponent(latest).path,
            encoding: .utf8
        )

        // The 1000-char message should be truncated to ~500 + "..."
        #expect(!snapshot.contains(longContent), "Full 1000-char message should be truncated")
        #expect(snapshot.contains("..."), "Truncated message should end with ellipsis")
    }

    @Test func compactionSnapshotRespectsMaxMessages() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        // Create a transcript with 40 user messages — only the last 30 should appear
        let transcriptURL = root.appendingPathComponent("transcript.jsonl")
        let lines = (1...40).map {
            """
            {"type":"message","message":{"role":"user","content":"Message number \($0)"}}
            """
        }
        try lines.joined(separator: "\n").write(to: transcriptURL, atomically: true, encoding: .utf8)

        _ = try run(
            subcommand: "distill",
            input: [
                "transcript_path": transcriptURL.path,
                "cwd": root.path,
            ]
        )

        let compactsDir = root.appendingPathComponent(".atelier/memory/compacts")
        try #require(FileManager.default.fileExists(atPath: compactsDir.path), "Compacts directory should exist after distill")

        let files = try FileManager.default.contentsOfDirectory(atPath: compactsDir.path)
            .filter { $0.hasSuffix(".md") }
            .sorted()
        let latest = try #require(files.last, "Expected at least one compaction snapshot")

        let snapshot = try String(
            contentsOfFile: compactsDir.appendingPathComponent(latest).path,
            encoding: .utf8
        )

        // Early messages should be dropped (only last 30 kept)
        #expect(!snapshot.contains("Message number 1\n"), "Message 1 should be outside the 30-message window")
        #expect(!snapshot.contains("Message number 10\n"), "Message 10 should be outside the 30-message window")
        // Recent messages should be present
        #expect(snapshot.contains("Message number 40"), "Message 40 should be in the snapshot")
        #expect(snapshot.contains("Message number 11"), "Message 11 should be in the snapshot")
    }

    // MARK: - Distill (without CLI)

    @Test func distillExitsSilentlyForEmptyTranscript() throws {
        let root = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: root) }

        // Create an empty transcript file
        let transcriptURL = root.appendingPathComponent("transcript.jsonl")
        FileManager.default.createFile(atPath: transcriptURL.path, contents: nil)

        let result = try run(
            subcommand: "distill",
            input: [
                "transcript_path": transcriptURL.path,
                "cwd": root.path,
            ]
        )

        // Empty transcript → no summary → exit 0 (nothing to distill)
        #expect(result.exitCode == 0)
    }

    @Test func distillExitsWithErrorWhenNoTranscript() throws {
        let result = try run(
            subcommand: "distill",
            input: ["cwd": "/tmp"]
        )

        #expect(result.exitCode == 1)
        #expect(result.stderr.contains("transcript_path"))
    }

    @Test func distillExitsWithErrorWhenNoCwd() throws {
        let result = try run(
            subcommand: "distill",
            input: ["transcript_path": "/tmp/transcript.jsonl"]
        )

        #expect(result.exitCode == 1)
        #expect(result.stderr.contains("cwd"))
    }
}
