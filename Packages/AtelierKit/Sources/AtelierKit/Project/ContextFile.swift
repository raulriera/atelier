import Foundation

/// A context file discovered in the project's directory hierarchy.
public struct ContextFile: Sendable, Equatable, Identifiable {

    /// How the context file is handled at runtime.
    public enum Source: Sendable, Equatable {
        /// `CLAUDE.md` — the CLI loads it natively; Atelier only shows it for visibility.
        case nativeCLI
        /// `COWORK.md`, `.atelier/context.md` — read and injected via `--append-system-prompt`.
        case injected
        /// `.atelier/memory/*.md` — auto-managed learnings injected with a read-only header.
        case memory
    }

    public var id: URL { url }

    /// Absolute URL of the file on disk.
    public let url: URL

    /// Display name (e.g. `CLAUDE.md`, `context.md`).
    public let filename: String

    /// Whether the CLI or Atelier is responsible for loading this file.
    public let source: Source

    public init(url: URL, filename: String, source: Source) {
        self.url = url
        self.filename = filename
        self.source = source
    }
}
