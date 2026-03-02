import Foundation
import AtelierSecurity

/// Registry and factory for project lifecycle management.
///
/// Persists known projects to `projects.json` within the base directory.
/// Each project gets its own subdirectory for scoped session persistence
/// and bookmark storage.
///
/// **Per-project directory layout:**
/// ```
/// {baseDirectory}/
///   projects.json                       <- registry
///   projects/
///     {projectID}/
///       sessions/                       <- DiskSessionPersistence base
///         {sessionId}.json
///       bookmarks.json                  <- DiskBookmarkStore file
/// ```
@MainActor
public final class ProjectStore {
    private var registry: [UUID: ProjectMetadata] = [:]
    private let baseDirectory: URL
    private let bookmarkCreator: BookmarkCreator

    /// Tracks project IDs already assigned during window restoration.
    /// Used by `nextRestoredProject()` to give each restored window a unique project.
    private var restoredIDs: Set<UUID> = []

    public init(baseDirectory: URL, bookmarkCreator: BookmarkCreator = SystemBookmarkCreator()) {
        self.baseDirectory = baseDirectory
        self.bookmarkCreator = bookmarkCreator
    }

    /// The default base directory inside Application Support.
    public static var defaultBaseDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Atelier", isDirectory: true)
    }

    // MARK: - Registry

    /// Loads the project registry from disk.
    public func load() throws {
        let fileURL = registryFileURL
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            registry = [:]
            return
        }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let projects = try decoder.decode([ProjectMetadata].self, from: data)
        registry = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0) })
    }

    /// Saves the project registry to disk.
    public func save() throws {
        let manager = FileManager.default
        if !manager.fileExists(atPath: baseDirectory.path) {
            try manager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(Array(registry.values))
        try data.write(to: registryFileURL, options: .atomic)
    }

    /// All known projects, sorted by most recently opened first.
    public func allProjects() -> [ProjectMetadata] {
        Array(registry.values).sorted { $0.lastOpenedAt > $1.lastOpenedAt }
    }

    /// Looks up a project by its ID.
    public func project(for id: UUID) -> ProjectMetadata? {
        registry[id]
    }

    /// Finds a project whose root URL matches the given URL.
    public func findProject(rootURL: URL) -> ProjectMetadata? {
        registry.values.first { $0.rootURL?.standardizedFileURL == rootURL.standardizedFileURL }
    }

    /// Returns the most recently opened project, or creates a scratchpad if none exist.
    ///
    /// Use this on launch when state restoration provides no project ID.
    /// Avoids creating duplicate scratchpads on every launch.
    public func openOrCreateProject() throws -> ProjectMetadata {
        if let mostRecent = allProjects().first {
            try touch(mostRecent.id)
            return mostRecent
        }
        return try createProject(rootURL: nil)
    }

    /// Returns the next project for a restored window, unique from previous calls.
    ///
    /// Each call returns a different project (most recent first). When all
    /// projects have been assigned, creates a scratchpad.
    ///
    /// Does NOT update `lastOpenedAt` — restoration should preserve the
    /// existing ordering so repeated launches are stable.
    public func nextRestoredProject() throws -> ProjectMetadata {
        let projects = allProjects()
        if let available = projects.first(where: { !restoredIDs.contains($0.id) }) {
            restoredIDs.insert(available.id)
            return available
        }
        let created = try createProject(rootURL: nil)
        restoredIDs.insert(created.id)
        return created
    }

    // MARK: - Lifecycle

    /// Creates a new project, persists it, and returns its metadata.
    ///
    /// - Parameter rootURL: The project root folder, or `nil` for a scratchpad.
    public func createProject(rootURL: URL?) throws -> ProjectMetadata {
        let kind: ProjectKind
        let displayName: String

        if let rootURL {
            kind = ProjectDetector.detect(at: rootURL)
            displayName = rootURL.lastPathComponent
        } else {
            kind = .unknown
            displayName = "Untitled"
        }

        let metadata = ProjectMetadata(
            rootURL: rootURL,
            displayName: displayName,
            detectedKind: kind
        )

        try ensureProjectDirectory(for: metadata.id)
        registry[metadata.id] = metadata
        try save()

        return metadata
    }

    /// Updates `lastOpenedAt` for the given project.
    public func touch(_ id: UUID) throws {
        guard var metadata = registry[id] else { return }
        metadata.lastOpenedAt = Date()
        registry[id] = metadata
        try save()
    }

    /// Removes a project from the registry and deletes its data directory.
    public func deleteProject(_ id: UUID) throws {
        registry[id] = nil

        let projectDir = projectDirectory(for: id)
        if FileManager.default.fileExists(atPath: projectDir.path) {
            try FileManager.default.removeItem(at: projectDir)
        }

        try save()
    }

    // MARK: - Factory

    /// Creates a live ``Project`` with scoped persistence and file access.
    public func materialize(_ id: UUID) throws -> Project {
        guard let metadata = registry[id] else {
            throw ProjectStoreError.projectNotFound(id)
        }

        let projectDir = projectDirectory(for: id)
        let sessionsDir = projectDir.appendingPathComponent("sessions", isDirectory: true)
        let bookmarksURL = projectDir.appendingPathComponent("bookmarks.json")

        try? FileManager.default.createDirectory(at: sessionsDir, withIntermediateDirectories: true)

        let sessionPersistence = DiskSessionPersistence(baseDirectory: sessionsDir)
        let bookmarkStore = DiskBookmarkStore(fileURL: bookmarksURL)
        let permissionManager = FilePermissionManager(
            store: bookmarkStore,
            bookmarkCreator: bookmarkCreator
        )
        let fileAccessStore = FileAccessStore(
            permissionManager: permissionManager,
            store: bookmarkStore
        )

        return Project(
            metadata: metadata,
            sessionPersistence: sessionPersistence,
            fileAccessStore: fileAccessStore
        )
    }

    // MARK: - Internal

    /// Stores a metadata entry directly without creating directories.
    /// Used by migration to insert pre-existing projects.
    func storeMetadata(_ metadata: ProjectMetadata) {
        registry[metadata.id] = metadata
    }

    func projectDirectory(for id: UUID) -> URL {
        baseDirectory
            .appendingPathComponent("projects", isDirectory: true)
            .appendingPathComponent(id.uuidString, isDirectory: true)
    }

    // MARK: - Private

    private var registryFileURL: URL {
        baseDirectory.appendingPathComponent("projects.json")
    }

    private func ensureProjectDirectory(for id: UUID) throws {
        let dir = projectDirectory(for: id)
        let sessionsDir = dir.appendingPathComponent("sessions", isDirectory: true)
        let manager = FileManager.default
        try manager.createDirectory(at: sessionsDir, withIntermediateDirectories: true)
    }
}

/// Errors from ``ProjectStore`` operations.
public enum ProjectStoreError: Error, Sendable {
    case projectNotFound(UUID)
}
