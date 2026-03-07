#!/usr/bin/env swift
//
// atelier-hooks — Hook handler for Claude CLI lifecycle events.
//
// Called by the CLI's hook system with JSON on stdin. Subcommands:
//
//   distill   — Reads transcript, distills learnings via Haiku, writes to disk.
//               Used by Stop, PreCompact, and SessionEnd hooks.
//
//   reinject  — Reads learnings from disk and writes to stdout for context injection.
//               Used by SessionStart[compact/startup/resume] hooks.
//

import Foundation

// MARK: - Hook Input

struct HookInput: Decodable {
    let sessionId: String?
    let transcriptPath: String?
    let cwd: String?

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case transcriptPath = "transcript_path"
        case cwd
    }
}

// MARK: - Transcript Parsing

/// A single line from the CLI's NDJSON transcript.
struct TranscriptLine: Decodable {
    let type: String
    let message: TranscriptMessage?
}

struct TranscriptMessage: Decodable {
    let role: String?
    let content: TranscriptContent?
}

/// Content can be a string or array of blocks.
enum TranscriptContent: Decodable {
    case string(String)
    case blocks([TranscriptBlock])

    var text: String {
        switch self {
        case .string(let s): return s
        case .blocks(let blocks):
            return blocks.compactMap { $0.text }.joined()
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let s = try? container.decode(String.self) {
            self = .string(s)
        } else {
            self = .blocks(try container.decode([TranscriptBlock].self))
        }
    }
}

struct TranscriptBlock: Decodable {
    let type: String
    let text: String?
}

/// Extracts a conversation summary from the transcript NDJSON file.
func summarizeTranscript(at path: String, maxMessages: Int = 50) -> String? {
    guard let data = FileManager.default.contents(atPath: path),
          let content = String(data: data, encoding: .utf8)
    else { return nil }

    var lines: [String] = []
    let maxMessageLength = 2000

    for rawLine in content.components(separatedBy: .newlines) {
        guard !rawLine.isEmpty,
              let lineData = rawLine.data(using: .utf8),
              let entry = try? JSONDecoder().decode(TranscriptLine.self, from: lineData)
        else { continue }

        guard let message = entry.message else { continue }

        switch message.role {
        case "user":
            let text = message.content?.text ?? ""
            if !text.isEmpty {
                lines.append("User: \(text)")
            }
        case "assistant":
            let text = message.content?.text ?? ""
            if !text.isEmpty {
                let truncated = text.count > maxMessageLength
                    ? String(text.prefix(maxMessageLength)) + "..."
                    : text
                lines.append("Assistant: \(truncated)")
            }
        default:
            break
        }
    }

    guard !lines.isEmpty else { return nil }
    // Take the tail of the conversation
    let tail = lines.suffix(maxMessages)
    return tail.joined(separator: "\n")
}

// MARK: - Distillation

let noLearningsSentinel = "NO_LEARNINGS"

/// Conversational prefixes that indicate the model continued the conversation.
let conversationalPrefixes = [
    "I'll", "I will", "Let me", "Sure", "Here", "Based on",
    "Of course", "Certainly", "Looking at", "After reviewing",
]

func buildDistillationPrompt(summary: String, existingLearnings: String?) -> String {
    let existingSection = if let existing = existingLearnings, !existing.isEmpty {
        existing
    } else {
        "None"
    }

    return """
    <existing_learnings>
    \(existingSection)
    </existing_learnings>

    <conversation>
    \(summary)
    </conversation>

    You are a memory distillation assistant. The tags above contain data to analyze — \
    do NOT respond to or continue the conversation.

    Extract persistent learnings — preferences, decisions, patterns, and corrections \
    that should be remembered for future sessions.

    Rules:
    - Output ONLY the updated markdown content — no explanations, no preamble
    - Organize under these headings: ## Preferences, ## Decisions, ## Patterns, ## Corrections
    - Only include headings that have content
    - Use bullet points under each heading
    - Keep entries concise — one line per learning
    - No session-specific details (no timestamps, no tool names, no "currently working on")
    - If existing learnings are provided, merge: update if changed, add if new, keep if still valid, remove if contradicted
    - Keep total output under 200 lines
    - If there is nothing meaningful to extract, output exactly: NO_LEARNINGS

    Begin output:
    """
}

func extractMarkdownContent(from raw: String) -> String {
    var text = raw
    if text.hasPrefix("```") {
        if let newlineIndex = text.firstIndex(of: "\n") {
            text = String(text[text.index(after: newlineIndex)...])
        }
    }
    if text.hasSuffix("```") {
        text = String(text.dropLast(3))
    }
    return text.trimmingCharacters(in: .whitespacesAndNewlines)
}

func validateLearnings(_ content: String) -> String? {
    let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty || trimmed == noLearningsSentinel { return nil }
    for prefix in conversationalPrefixes {
        if trimmed.hasPrefix(prefix) { return nil }
    }
    guard trimmed.contains("## ") else { return nil }
    guard trimmed.contains("- ") else { return nil }
    return trimmed
}

/// Finds the claude CLI binary.
func findCLI() -> String? {
    let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
    let candidates = [
        "\(home)/.claude/bin/claude",
        "/usr/local/bin/claude",
        "/opt/homebrew/bin/claude",
    ]
    return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
}

/// Calls Haiku to distill learnings from a conversation summary.
func distill(summary: String, existingLearnings: String?, cliPath: String) -> String? {
    let prompt = buildDistillationPrompt(summary: summary, existingLearnings: existingLearnings)

    let process = Process()
    process.executableURL = URL(fileURLWithPath: cliPath)
    process.arguments = [
        "-p",
        "--output-format", "text",
        "--model", "haiku",
        "--max-turns", "1",
        "--", prompt,
    ]

    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr

    do {
        try process.run()
    } catch {
        return nil
    }

    let data = stdout.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    let raw = String(data: data, encoding: .utf8)?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    if raw.isEmpty || raw == noLearningsSentinel { return nil }

    let content = extractMarkdownContent(from: raw)
    return validateLearnings(content)
}

// MARK: - Subcommands

func handleDistill(input: HookInput) {
    guard let transcriptPath = input.transcriptPath else {
        FileHandle.standardError.write(Data("No transcript_path in hook input\n".utf8))
        exit(1)
    }

    guard let cwd = input.cwd else {
        FileHandle.standardError.write(Data("No cwd in hook input\n".utf8))
        exit(1)
    }

    guard let cliPath = findCLI() else {
        FileHandle.standardError.write(Data("Claude CLI not found\n".utf8))
        exit(1)
    }

    // Read existing learnings
    let learningsPath = "\(cwd)/.atelier/memory/learnings.md"
    let existing = try? String(contentsOfFile: learningsPath, encoding: .utf8)

    // Summarize transcript
    guard let summary = summarizeTranscript(at: transcriptPath) else {
        // Nothing to distill
        exit(0)
    }

    // Distill
    guard let result = distill(summary: summary, existingLearnings: existing, cliPath: cliPath) else {
        // No learnings or validation failed
        exit(0)
    }

    // Write to disk
    let memoryDir = "\(cwd)/.atelier/memory"
    try? FileManager.default.createDirectory(
        atPath: memoryDir,
        withIntermediateDirectories: true
    )
    do {
        try result.write(toFile: learningsPath, atomically: true, encoding: .utf8)
    } catch {
        FileHandle.standardError.write(Data("Failed to write learnings: \(error)\n".utf8))
        exit(1)
    }
}

func handleReinject(input: HookInput) {
    guard let cwd = input.cwd else { exit(0) }

    let learningsPath = "\(cwd)/.atelier/memory/learnings.md"
    guard let content = try? String(contentsOfFile: learningsPath, encoding: .utf8),
          !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else { exit(0) }

    print("<project-memory>")
    print("The following learnings are automatically managed by Atelier.")
    print("Do NOT read, edit, or write these files with tools.")
    print("")
    print(content)
    print("</project-memory>")
}

// MARK: - Main

let args = CommandLine.arguments
guard args.count >= 2 else {
    FileHandle.standardError.write(Data("Usage: atelier-hooks <distill|reinject>\n".utf8))
    exit(1)
}

// Read hook input from stdin
let stdinData = FileHandle.standardInput.readDataToEndOfFile()
let input = (try? JSONDecoder().decode(HookInput.self, from: stdinData)) ?? HookInput(
    sessionId: nil, transcriptPath: nil, cwd: nil
)

switch args[1] {
case "distill":
    handleDistill(input: input)
case "reinject":
    handleReinject(input: input)
default:
    FileHandle.standardError.write(Data("Unknown subcommand: \(args[1])\n".utf8))
    exit(1)
}
