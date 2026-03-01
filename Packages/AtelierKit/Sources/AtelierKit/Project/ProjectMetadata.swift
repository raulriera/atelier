import Foundation

/// Serializable record describing a project, stored in the registry.
public struct ProjectMetadata: Sendable, Codable, Identifiable {
    public let id: UUID
    public var rootURL: URL?
    public var displayName: String
    public var detectedKind: ProjectKind
    public var createdAt: Date
    public var lastOpenedAt: Date
    public var rootBookmarkData: Data?

    public init(
        id: UUID = UUID(),
        rootURL: URL? = nil,
        displayName: String = "Untitled",
        detectedKind: ProjectKind = .unknown,
        createdAt: Date = Date(),
        lastOpenedAt: Date = Date(),
        rootBookmarkData: Data? = nil
    ) {
        self.id = id
        self.rootURL = rootURL
        self.displayName = displayName
        self.detectedKind = detectedKind
        self.createdAt = createdAt
        self.lastOpenedAt = lastOpenedAt
        self.rootBookmarkData = rootBookmarkData
    }
}
