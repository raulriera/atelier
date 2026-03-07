import Foundation

/// Manages the `.atelier/memory/` directory on disk for persistent learnings.
///
/// Memory is organized into category files (`preferences.md`, `decisions.md`,
/// `patterns.md`, `corrections.md`).
public struct MemoryStore: Sendable {
    /// The project root directory containing `.atelier/memory/`.
    public let projectRoot: URL

    public init(projectRoot: URL) {
        self.projectRoot = projectRoot
    }

    /// The `.atelier/memory/` directory within the project root.
    public var memoryDirectory: URL {
        projectRoot
            .appendingPathComponent(".atelier", isDirectory: true)
            .appendingPathComponent("memory", isDirectory: true)
    }

    /// Known category files and the `## ` heading they correspond to.
    public static let categories: [(heading: String, filename: String)] = [
        ("## Preferences", "preferences.md"),
        ("## Decisions", "decisions.md"),
        ("## Patterns", "patterns.md"),
        ("## Corrections", "corrections.md"),
    ]

    /// Reads all memory files and returns their combined content, or `nil` if empty.
    public func readAll() -> String? {
        let manager = FileManager.default
        guard let files = try? manager.contentsOfDirectory(
            at: memoryDirectory,
            includingPropertiesForKeys: nil
        ) else { return nil }

        let parts = files
            .filter { $0.pathExtension == "md" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url -> String? in
                guard let content = try? String(contentsOf: url, encoding: .utf8),
                      !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else { return nil }
                return content
            }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: "\n\n")
    }

    /// Reads a single category file.
    public func read(category: String) -> String? {
        guard let filename = Self.categories.first(where: { $0.heading == category })?.filename
        else { return nil }
        let url = memoryDirectory.appendingPathComponent(filename)
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Writes content to a category file, creating the directory if needed.
    public func write(category: String, content: String) throws {
        guard let filename = Self.categories.first(where: { $0.heading == category })?.filename
        else { return }
        try FileManager.default.createDirectory(at: memoryDirectory, withIntermediateDirectories: true)
        let url = memoryDirectory.appendingPathComponent(filename)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Lists all memory files that exist on disk.
    public func listFiles() -> [URL] {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: memoryDirectory,
            includingPropertiesForKeys: nil
        ) else { return [] }

        return files
            .filter { $0.pathExtension == "md" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
}
