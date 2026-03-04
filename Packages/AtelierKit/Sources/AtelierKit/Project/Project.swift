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
    public let capabilityStore: CapabilityStore

    public init(
        metadata: ProjectMetadata,
        sessionPersistence: SessionPersistence,
        fileAccessStore: FileAccessStore,
        capabilityStore: CapabilityStore
    ) {
        self.id = metadata.id
        self.rootURL = metadata.rootURL
        self.displayName = metadata.displayName
        self.detectedKind = metadata.detectedKind
        self.sessionPersistence = sessionPersistence
        self.fileAccessStore = fileAccessStore
        self.capabilityStore = capabilityStore
    }

    /// Updates the project root, triggering SwiftUI re-evaluation via @Observable.
    public func updateRoot(url: URL) {
        rootURL = url
        displayName = url.lastPathComponent
        detectedKind = ProjectDetector.detect(at: url)
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
