import Foundation

/// Persistence layer for security-scoped bookmark entries.
public protocol BookmarkStore: Sendable {
    func save(_ entry: BookmarkEntry) async throws
    func entry(for url: URL) async -> BookmarkEntry?
    func allEntries() async -> [BookmarkEntry]
    func remove(for url: URL) async
}
