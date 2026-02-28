import Foundation

/// In-memory bookmark store for testing and early development.
public actor InMemoryBookmarkStore: BookmarkStore {
    private var entries: [URL: BookmarkEntry] = [:]

    public init() {}

    public func save(_ entry: BookmarkEntry) {
        entries[entry.url] = entry
    }

    public func entry(for url: URL) -> BookmarkEntry? {
        entries[url]
    }

    public func allEntries() -> [BookmarkEntry] {
        Array(entries.values)
    }

    public func remove(for url: URL) {
        entries[url] = nil
    }
}
