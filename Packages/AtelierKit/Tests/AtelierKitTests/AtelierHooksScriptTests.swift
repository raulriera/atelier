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
