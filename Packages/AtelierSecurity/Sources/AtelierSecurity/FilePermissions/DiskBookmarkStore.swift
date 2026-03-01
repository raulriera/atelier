import Foundation

/// Disk-backed bookmark store that persists entries as JSON.
///
/// Maintains a write-through in-memory cache, flushing to disk on every
/// `save()` and `remove()`. Loads existing entries from disk at init.
///
/// When `reloadBeforeRead` is `true`, `allEntries()` re-reads from disk
/// before returning — useful in cross-process (XPC) scenarios where another
/// process may write the file.
public actor DiskBookmarkStore: BookmarkStore {
    private var entries: [URL: BookmarkEntry] = [:]
    private let fileURL: URL
    private let persistence: BookmarkPersistence
    private let reloadBeforeRead: Bool

    public init(
        fileURL: URL,
        persistence: BookmarkPersistence = SystemBookmarkPersistence(),
        reloadBeforeRead: Bool = false
    ) {
        self.fileURL = fileURL
        self.persistence = persistence
        self.reloadBeforeRead = reloadBeforeRead
        self.entries = Self.loadEntries(from: fileURL, persistence: persistence)
    }

    public func save(_ entry: BookmarkEntry) throws {
        entries[entry.url] = entry
        try flush()
    }

    public func entry(for url: URL) -> BookmarkEntry? {
        entries[url]
    }

    public func allEntries() -> [BookmarkEntry] {
        if reloadBeforeRead {
            entries = Self.loadEntries(from: fileURL, persistence: persistence)
        }
        return Array(entries.values)
    }

    public func remove(for url: URL) {
        entries[url] = nil
        try? flush()
    }

    private func flush() throws {
        let data: Data
        do {
            data = try JSONEncoder().encode(Array(entries.values))
        } catch {
            throw BookmarkStoreError.writeFailed(
                path: fileURL.path,
                underlying: error.localizedDescription
            )
        }
        do {
            try persistence.write(data, to: fileURL)
        } catch {
            throw BookmarkStoreError.writeFailed(
                path: fileURL.path,
                underlying: error.localizedDescription
            )
        }
    }

    private static func loadEntries(
        from url: URL,
        persistence: BookmarkPersistence
    ) -> [URL: BookmarkEntry] {
        guard let data = try? persistence.read(from: url) else {
            return [:]
        }
        guard let decoded = try? JSONDecoder().decode([BookmarkEntry].self, from: data) else {
            return [:]
        }
        return Dictionary(uniqueKeysWithValues: decoded.map { ($0.url, $0) })
    }
}
