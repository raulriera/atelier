import Foundation

/// Manages the `.atelier/memory/` directory on disk for persistent learnings.
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

    /// The `learnings.md` file within the memory directory.
    public var learningsURL: URL {
        memoryDirectory.appendingPathComponent("learnings.md")
    }

    /// Reads the current learnings file, returning `nil` if absent or unreadable.
    public func readLearnings() -> String? {
        try? String(contentsOf: learningsURL, encoding: .utf8)
    }

    /// Writes learnings to disk, creating `.atelier/memory/` if needed.
    public func writeLearnings(_ content: String) throws {
        try FileManager.default.createDirectory(at: memoryDirectory, withIntermediateDirectories: true)
        try content.write(to: learningsURL, atomically: true, encoding: .utf8)
    }
}
