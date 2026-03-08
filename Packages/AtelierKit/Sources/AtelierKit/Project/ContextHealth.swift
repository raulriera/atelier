import Foundation

/// A snapshot of a project's living context health — file sizes, token estimates,
/// and compaction state. Used for debugging and monitoring context growth.
public struct ContextHealth: Sendable {

    /// A single file in the context system with its metadata.
    public struct FileEntry: Sendable, Identifiable {
        public var id: String { path }
        public let path: String
        public let filename: String
        public let byteSize: Int
        public let lineCount: Int
        public let source: Source

        /// Rough token estimate (~4 characters per token for English text).
        public var estimatedTokens: Int { max(1, byteSize / 4) }

        public enum Source: String, Sendable {
            case alwaysInject = "Always Inject"
            case manifest = "Manifest"
            case injected = "Injected"
            case nativeCLI = "Native CLI"
            case structureMap = "Structure Map"
            case compactionSnapshot = "Compaction Snapshot"
        }
    }

    /// All context files discovered for this project.
    public let files: [FileEntry]

    /// Number of compaction snapshots on disk.
    public let compactionSnapshotCount: Int

    /// Timestamp of the most recent compaction snapshot, if any.
    public let latestCompactionDate: Date?

    /// Total bytes of all always-injected content.
    public var alwaysInjectedBytes: Int {
        files.filter { $0.source == .alwaysInject || $0.source == .injected }
            .reduce(0) { $0 + $1.byteSize }
    }

    /// Total estimated tokens for always-injected content.
    public var alwaysInjectedTokens: Int {
        files.filter { $0.source == .alwaysInject || $0.source == .injected }
            .reduce(0) { $0 + $1.estimatedTokens }
    }

    /// Total bytes across all context files.
    public var totalBytes: Int {
        files.reduce(0) { $0 + $1.byteSize }
    }

    /// Total estimated tokens across all context files.
    public var totalTokens: Int {
        files.reduce(0) { $0 + $1.estimatedTokens }
    }

    /// Scans the project root and builds a health snapshot.
    public static func scan(projectRoot: URL) -> ContextHealth {
        let manager = FileManager.default
        let memoryDir = projectRoot
            .appendingPathComponent(".atelier", isDirectory: true)
            .appendingPathComponent("memory", isDirectory: true)
        let compactsDir = memoryDir.appendingPathComponent("compacts", isDirectory: true)
        let alwaysInjectFilenames: Set<String> = ["preferences.md", "corrections.md"]

        var entries: [FileEntry] = []

        // Context files (COWORK.md, .atelier/context.md)
        let contextFiles = ContextFileLoader.discover(from: projectRoot)
        for file in contextFiles {
            let source: FileEntry.Source = switch file.source {
            case .nativeCLI: .nativeCLI
            case .injected: .injected
            case .memory:
                alwaysInjectFilenames.contains(file.filename)
                    ? .alwaysInject : .manifest
            }
            if let entry = fileEntry(at: file.url, source: source) {
                entries.append(entry)
            }
        }

        // Structure map
        let structureMapURL = projectRoot
            .appendingPathComponent(".atelier", isDirectory: true)
            .appendingPathComponent("structure.json")
        if let entry = fileEntry(at: structureMapURL, source: .structureMap) {
            entries.append(entry)
        }

        // Compaction snapshots
        var snapshotCount = 0
        var latestDate: Date?
        if let snapshotFiles = try? manager.contentsOfDirectory(
            at: compactsDir,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) {
            let mdFiles = snapshotFiles.filter { $0.pathExtension == "md" }
            snapshotCount = mdFiles.count

            for url in mdFiles {
                if let entry = fileEntry(at: url, source: .compactionSnapshot) {
                    entries.append(entry)
                }
                if let attrs = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
                   let date = attrs.contentModificationDate {
                    if latestDate == nil || date > latestDate! {
                        latestDate = date
                    }
                }
            }
        }

        return ContextHealth(
            files: entries,
            compactionSnapshotCount: snapshotCount,
            latestCompactionDate: latestDate
        )
    }

    private static func fileEntry(at url: URL, source: FileEntry.Source) -> FileEntry? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int
        else { return nil }

        let lineCount: Int
        if let content = try? String(contentsOf: url, encoding: .utf8) {
            lineCount = content.components(separatedBy: .newlines).count
        } else {
            lineCount = 0
        }

        return FileEntry(
            path: url.path,
            filename: url.lastPathComponent,
            byteSize: size,
            lineCount: lineCount,
            source: source
        )
    }
}
