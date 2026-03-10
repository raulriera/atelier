import Foundation

/// Stateless scanner that discovers context files by walking up the directory tree.
public enum ContextFileLoader {

    /// Well-known context filenames and their sources.
    private static let candidates: [(path: String, source: ContextFile.Source)] = [
        ("CLAUDE.md", .nativeCLI),
        ("COWORK.md", .injected),
        (".atelier/context.md", .injected),
    ]

    /// Discovers context files from `projectRoot` up to the user's home directory.
    ///
    /// Returns results in child-first order (project root files appear before parent files).
    /// Memory files (`.atelier/memory/*.md`) are only scanned at the project root itself.
    public static func discover(from projectRoot: URL) -> [ContextFile] {
        let manager = FileManager.default
        let home = homeDirectory

        var results: [ContextFile] = []
        var directory = projectRoot.standardized
        var isProjectRoot = true

        while true {
            for candidate in candidates {
                let fileURL = directory.appendingPathComponent(candidate.path)
                if manager.fileExists(atPath: fileURL.path) {
                    results.append(ContextFile(
                        url: fileURL,
                        filename: fileURL.lastPathComponent,
                        source: candidate.source
                    ))
                }
            }

            // Scan .atelier/memory/*.md only at the project root.
            if isProjectRoot {
                results += discoverMemoryFiles(in: directory, manager: manager)
                isProjectRoot = false
            }

            // Stop at the home directory or filesystem root.
            let path = directory.path
            if path == home || path == "/" {
                break
            }

            let parent = directory.deletingLastPathComponent().standardized
            if parent.path == directory.path {
                break
            }
            directory = parent
        }

        return results
    }

    /// Scans `.atelier/memory/` for markdown files to inject as context.
    private static func discoverMemoryFiles(
        in directory: URL,
        manager: FileManager
    ) -> [ContextFile] {
        let memoryDir = directory
            .appendingPathComponent(".atelier", isDirectory: true)
            .appendingPathComponent("memory", isDirectory: true)

        guard manager.fileExists(atPath: memoryDir.path) else { return [] }

        guard let contents = try? manager.contentsOfDirectory(
            at: memoryDir,
            includingPropertiesForKeys: nil
        ) else { return [] }

        return contents
            .filter { $0.pathExtension == "md" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .map { url in
                // contentsOfDirectory resolves symlinks (e.g. /var → /private/var);
                // rebuild via the known parent so paths stay consistent.
                let consistent = memoryDir.appendingPathComponent(url.lastPathComponent)
                return ContextFile(
                    url: consistent,
                    filename: url.lastPathComponent,
                    source: .memory
                )
            }
    }

    /// Whether the discovered files include any project-specific context
    /// (injected context files or memory). Returns `false` for a brand-new
    /// project that has no COWORK.md, .atelier/context.md, or memory files.
    public static func hasProjectContext(_ files: [ContextFile]) -> Bool {
        files.contains { $0.source == .injected || $0.source == .memory }
    }

    /// Memory files that are always injected in full (high-value, small).
    /// Everything else is listed as a manifest entry for on-demand reading.
    private static let alwaysInjectFilenames: Set<String> = [
        "preferences.md",
        "corrections.md",
    ]

    /// Hard cap for always-inject files. If distillation fails to keep a file
    /// compact, we truncate at injection time rather than blowing the context window.
    /// 40 lines accommodates a heading + 30 bullet entries with some slack.
    static let maxAlwaysInjectLines = 40

    /// Reads injectable files and concatenates their content.
    ///
    /// Returns `nil` when there are no injectable files or all are empty,
    /// so callers can skip the `--append-system-prompt` flag entirely.
    ///
    /// Memory files use smart loading: `preferences.md` and `corrections.md`
    /// are always injected in full. Other memory files appear as a manifest
    /// so Claude can read them on demand when a topic comes up.
    ///
    /// Defense-in-depth: if an always-inject file exceeds `maxAlwaysInjectLines`,
    /// only the first portion is injected with a note to read the full file on demand.
    public static func contentForInjection(from files: [ContextFile]) -> String? {
        var parts: [String] = []
        var alwaysInjectContents: [String] = []
        var manifestEntries: [String] = []

        for file in files {
            switch file.source {
            case .nativeCLI:
                continue

            case .injected:
                guard let content = try? String(contentsOf: file.url, encoding: .utf8),
                      !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else { continue }
                parts.append(content)

            case .memory:
                guard let content = try? String(contentsOf: file.url, encoding: .utf8),
                      !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else { continue }

                if alwaysInjectFilenames.contains(file.filename) {
                    alwaysInjectContents.append(
                        capContent(content, filename: file.filename)
                    )
                } else {
                    let preview = content.components(separatedBy: .newlines)
                        .first { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? file.filename
                    manifestEntries.append("- \(file.filename): \(preview)")
                }
            }
        }

        // Build the project-memory block
        if !alwaysInjectContents.isEmpty || !manifestEntries.isEmpty {
            var memoryBlock = """
            <project-memory>
            The following learnings are automatically managed by the app. \
            Do NOT read, edit, or write these files with tools. \
            They update automatically after each conversation.
            """

            for content in alwaysInjectContents {
                memoryBlock += "\n\n\(content)"
            }

            if !manifestEntries.isEmpty {
                memoryBlock += "\n\n"
                memoryBlock += "Additional memory files available (read with the Read tool when relevant):\n"
                memoryBlock += manifestEntries.joined(separator: "\n")
            }

            memoryBlock += "\n</project-memory>"
            parts.append(memoryBlock)
        }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: "\n\n---\n\n")
    }

    /// Truncates content to `maxAlwaysInjectLines` if it exceeds the budget.
    ///
    /// When truncated, appends a note telling Claude the file was capped and
    /// the full version is available via the Read tool.
    private static func capContent(_ content: String, filename: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        guard lines.count > maxAlwaysInjectLines else { return content }
        let kept = lines.prefix(maxAlwaysInjectLines).joined(separator: "\n")
        return kept + "\n(...truncated — read .atelier/memory/\(filename) for full content)"
    }

    private static var homeDirectory: String {
        CLIDiscovery.realHomeDirectory
    }
}
