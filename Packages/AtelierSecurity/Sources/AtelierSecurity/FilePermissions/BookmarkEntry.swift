import Foundation

/// A persisted security-scoped bookmark with its metadata.
public struct BookmarkEntry: Sendable, Identifiable, Codable {
    public let id: UUID
    public let url: URL
    public let bookmarkData: Data
    public let permission: FilePermission
    public let createdAt: Date
    public var lastAccessedAt: Date?
    public var isStale: Bool

    public init(
        id: UUID = UUID(),
        url: URL,
        bookmarkData: Data,
        permission: FilePermission,
        createdAt: Date = Date(),
        lastAccessedAt: Date? = nil,
        isStale: Bool = false
    ) {
        self.id = id
        self.url = url
        self.bookmarkData = bookmarkData
        self.permission = permission
        self.createdAt = createdAt
        self.lastAccessedAt = lastAccessedAt
        self.isStale = isStale
    }
}
