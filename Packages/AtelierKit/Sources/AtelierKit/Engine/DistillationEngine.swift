import Foundation
import os

/// Spawns a background CLI process to distill conversation learnings into persistent memory.
public actor DistillationEngine {
    private static let logger = Logger(subsystem: "com.atelier.kit", category: "DistillationEngine")

    /// Sentinel output — haiku returns this when there's nothing worth saving.
    static let noLearningsSentinel = "NO_LEARNINGS"

    private var activeTask: Task<String?, Never>?
    private let cliPath: String

    public init(cliPath: String? = nil) {
        self.cliPath = cliPath ?? CLIDiscovery.findCLI()
    }

    /// Distills a conversation summary into updated learnings.
    ///
    /// Cancels any previous in-flight distillation. Runs haiku in single-shot mode
    /// and returns the updated markdown, or `nil` if nothing worth saving.
    public func distill(
        conversationSummary: String,
        existingLearnings: String?,
        workingDirectory: URL
    ) async -> String? {
        activeTask?.cancel()

        let prompt = buildDistillationPrompt(
            conversationSummary: conversationSummary,
            existingLearnings: existingLearnings
        )
        let path = cliPath

        let task = Task<String?, Never> {
            do {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = [
                    "-p",
                    "--output-format", "text",
                    "--model", "haiku",
                    "--max-turns", "1",
                    "--", prompt,
                ]
                process.currentDirectoryURL = workingDirectory

                let stdout = Pipe()
                let stderr = Pipe()
                process.standardOutput = stdout
                process.standardError = stderr

                try process.run()

                // Read stdout BEFORE waitUntilExit to avoid deadlock if the
                // pipe buffer fills. readDataToEndOfFile blocks until the pipe
                // closes (process exits), so waitUntilExit returns immediately.
                let data = stdout.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                if Task.isCancelled { return nil }

                let raw = String(data: data, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                if raw.isEmpty || raw == Self.noLearningsSentinel {
                    Self.logger.debug("Distillation produced no learnings")
                    return nil
                }

                let content = extractMarkdownContent(from: raw)
                Self.logger.debug("Distillation produced \(content.count) characters")
                return content
            } catch {
                Self.logger.error("Distillation failed: \(error.localizedDescription, privacy: .public)")
                return nil
            }
        }

        activeTask = task
        return await task.value
    }

    /// Cancels any in-flight distillation.
    public func cancel() {
        activeTask?.cancel()
        activeTask = nil
    }

    // MARK: - Prompt Construction

    func buildDistillationPrompt(
        conversationSummary: String,
        existingLearnings: String?
    ) -> String {
        var parts: [String] = []

        parts.append("""
        You are a memory distillation assistant. Review the conversation below and extract \
        persistent learnings — preferences, decisions, patterns, and corrections that should \
        be remembered for future sessions.

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
        """)

        if let existing = existingLearnings, !existing.isEmpty {
            parts.append("--- EXISTING LEARNINGS ---")
            parts.append(existing)
        }

        parts.append("--- CONVERSATION ---")
        parts.append(conversationSummary)

        return parts.joined(separator: "\n\n")
    }

    // MARK: - Output Processing

    /// Strips markdown code fences if the model wraps its output in them.
    func extractMarkdownContent(from raw: String) -> String {
        var text = raw

        // Strip leading ```markdown or ```
        if text.hasPrefix("```") {
            if let newlineIndex = text.firstIndex(of: "\n") {
                text = String(text[text.index(after: newlineIndex)...])
            }
        }

        // Strip trailing ```
        if text.hasSuffix("```") {
            text = String(text.dropLast(3))
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
