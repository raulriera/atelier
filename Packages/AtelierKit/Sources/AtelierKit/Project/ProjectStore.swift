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

    /// Tracks project IDs already claimed during window restoration this launch.
    /// Ensures each restored window gets a unique existing project.
    private var claimedIDs: Set<UUID> = []

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

    /// Returns the next unclaimed project for a restored window.
    ///
    /// Prefers projects with a root URL (real projects) over nil-root scratchpads,
    /// then falls back to scratchpads, then creates a new one. Each call returns
    /// a different project so multiple restored windows get unique projects.
    ///
    /// Does not update `lastOpenedAt` — restoration preserves existing ordering.
    public func nextUnclaimedProject() throws -> ProjectMetadata {
        let unclaimed = allProjects().filter { !claimedIDs.contains($0.id) }
        let pick = unclaimed.first(where: { $0.rootURL != nil }) ?? unclaimed.first
        if let pick {
            claimedIDs.insert(pick.id)
            return pick
        }
        let created = try createProject(rootURL: nil)
        claimedIDs.insert(created.id)
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

    /// Updates the root URL, display name, and detected kind for an existing project.
    public func updateProjectRoot(_ id: UUID, rootURL: URL) throws {
        guard var metadata = registry[id] else { return }
        metadata.rootURL = rootURL
        metadata.displayName = rootURL.lastPathComponent
        metadata.detectedKind = ProjectDetector.detect(at: rootURL)
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

        let capabilitiesURL = projectDir.appendingPathComponent("capabilities.json")
        let capabilityStore = CapabilityStore(persistenceURL: capabilitiesURL)

        return Project(
            metadata: metadata,
            sessionPersistence: sessionPersistence,
            fileAccessStore: fileAccessStore,
            capabilityStore: capabilityStore
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
