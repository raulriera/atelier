import Foundation

/// Stateless scanner that discovers context files by walking up the directory tree.
public enum ContextFileLoader {

    /// Well-known context filenames and their sources.
    private static let candidates: [(path: String, source: ContextFile.Source)] = [
        ("CLAUDE.md", .nativeCLI),
        ("COWORK.md", .atelierInjected),
        (".atelier/context.md", .atelierInjected),
    ]

    /// Discovers context files from `projectRoot` up to the user's home directory.
    ///
    /// Returns results in child-first order (project root files appear before parent files).
    public static func discover(from projectRoot: URL) -> [ContextFile] {
        let manager = FileManager.default
        let home = homeDirectory

        var results: [ContextFile] = []
        var directory = projectRoot.standardized

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

    /// Reads all `.atelierInjected` files and concatenates their content.
    ///
    /// Returns `nil` when there are no injected files or all are empty,
    /// so callers can skip the `--append-system-prompt` flag entirely.
    public static func contentForInjection(from files: [ContextFile]) -> String? {
        let parts = files
            .filter { $0.source == .atelierInjected }
            .compactMap { file -> String? in
                guard let content = try? String(contentsOf: file.url, encoding: .utf8),
                      !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else { return nil }
                return content
            }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: "\n\n---\n\n")
    }

    /// The real user home directory, bypassing sandbox container redirection.
    private static var homeDirectory: String {
        if let pw = getpwuid(getuid()) {
            return String(cString: pw.pointee.pw_dir)
        }
        return NSHomeDirectory()
    }
}
