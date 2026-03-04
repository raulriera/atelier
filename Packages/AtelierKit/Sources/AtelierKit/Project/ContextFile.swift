import Foundation

/// A context file discovered in the project's directory hierarchy.
public struct ContextFile: Sendable, Equatable, Identifiable {

    /// How the context file is handled at runtime.
    public enum Source: Sendable, Equatable {
        /// `CLAUDE.md` — the CLI loads it natively; Atelier only shows it for visibility.
        case nativeCLI
        /// `COWORK.md`, `.atelier/context.md` — Atelier reads the content and injects it
        /// via `--append-system-prompt`.
        case atelierInjected
        /// `.atelier/memory/*.md` — auto-managed learnings injected with a read-only header.
        case atelierMemory
    }

    public var id: URL { url }

    /// Absolute URL of the file on disk.
    public let url: URL

    /// Display name (e.g. `CLAUDE.md`, `context.md`).
    public let filename: String

    /// Whether the CLI or Atelier is responsible for loading this file.
    public let source: Source
}
