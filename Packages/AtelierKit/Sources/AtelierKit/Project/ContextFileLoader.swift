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

    /// Reads all injectable files and concatenates their content.
    ///
    /// Returns `nil` when there are no injectable files or all are empty,
    /// so callers can skip the `--append-system-prompt` flag entirely.
    ///
    /// Memory files are wrapped with an instruction telling the agent
    /// they are auto-managed and should not be edited directly.
    public static func contentForInjection(from files: [ContextFile]) -> String? {
        let parts = files
            .filter { $0.source == .injected || $0.source == .memory }
            .compactMap { file -> String? in
                guard let content = try? String(contentsOf: file.url, encoding: .utf8),
                      !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else { return nil }

                if file.source == .memory {
                    return """
                    <project-memory>
                    The following learnings are automatically managed by the app. \
                    Do NOT read, edit, or write these files with tools. \
                    They update automatically after each conversation.

                    \(content)
                    </project-memory>
                    """
                }

                return content
            }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: "\n\n---\n\n")
    }

    private static var homeDirectory: String {
        CLIDiscovery.realHomeDirectory
    }
}
