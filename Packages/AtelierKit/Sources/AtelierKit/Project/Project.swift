import Foundation

/// Live observable model representing an open project.
///
/// Holds scoped dependencies for session persistence and file access.
/// Created by ``ProjectStore/materialize(_:)`` — does not create its own
/// dependencies, keeping it testable with in-memory implementations.
@Observable
public final class Project: Identifiable {
    public let id: UUID
    public private(set) var rootURL: URL?
    public private(set) var displayName: String
    public private(set) var detectedKind: ProjectKind
    public let sessionPersistence: SessionPersistence
    public let fileAccessStore: FileAccessStore

    public init(
        metadata: ProjectMetadata,
        sessionPersistence: SessionPersistence,
        fileAccessStore: FileAccessStore
    ) {
        self.id = metadata.id
        self.rootURL = metadata.rootURL
        self.displayName = metadata.displayName
        self.detectedKind = metadata.detectedKind
        self.sessionPersistence = sessionPersistence
        self.fileAccessStore = fileAccessStore
    }

    /// Produces a snapshot of the current state as serializable metadata.
    public func metadata(rootBookmarkData: Data? = nil) -> ProjectMetadata {
        ProjectMetadata(
            id: id,
            rootURL: rootURL,
            displayName: displayName,
            detectedKind: detectedKind,
            createdAt: Date(),
            lastOpenedAt: Date(),
            rootBookmarkData: rootBookmarkData
        )
    }
}
