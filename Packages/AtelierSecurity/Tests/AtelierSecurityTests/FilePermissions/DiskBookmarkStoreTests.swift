import Foundation
import Testing
@testable import AtelierSecurity

// MARK: - Mock Persistence

private final class MockBookmarkPersistence: BookmarkPersistence, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [URL: Data] = [:]
    var shouldFailOnWrite = false

    func read(from url: URL) throws -> Data {
        lock.lock()
        defer { lock.unlock() }
        guard let data = storage[url] else {
            throw BookmarkStoreError.readFailed(
                path: url.path,
                underlying: "file not found"
            )
        }
        return data
    }

    func write(_ data: Data, to url: URL) throws {
        lock.lock()
        defer { lock.unlock() }
        if shouldFailOnWrite {
            throw BookmarkStoreError.writeFailed(
                path: url.path,
                underlying: "simulated write failure"
            )
        }
        storage[url] = data
    }

    func storedData(for url: URL) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return storage[url]
    }
}

// MARK: - Tests

@Suite("DiskBookmarkStore")
struct DiskBookmarkStoreTests {

    private func makeEntry(
        path: String,
        permission: FilePermission = .readWrite
    ) -> BookmarkEntry {
        BookmarkEntry(
            url: URL(fileURLWithPath: path),
            bookmarkData: Data([0x01]),
            permission: permission
        )
    }

    @Test func savePersistsToDiskAndLoadOnInitReads() async throws {
        let persistence = MockBookmarkPersistence()
        let fileURL = URL(fileURLWithPath: "/tmp/bookmarks.json")
        let entry = makeEntry(path: "/project/src")

        let store = DiskBookmarkStore(fileURL: fileURL, persistence: persistence)
        try await store.save(entry)

        // Data was written to disk
        #expect(persistence.storedData(for: fileURL) != nil)

        // New store instance reads it back
        let store2 = DiskBookmarkStore(fileURL: fileURL, persistence: persistence)
        let loaded = await store2.allEntries()
        #expect(loaded.count == 1)
        #expect(loaded[0].url == entry.url)
        #expect(loaded[0].permission == .readWrite)
    }

    @Test func roundTripsMultipleEntries() async throws {
        let persistence = MockBookmarkPersistence()
        let fileURL = URL(fileURLWithPath: "/tmp/bookmarks.json")
        let store = DiskBookmarkStore(fileURL: fileURL, persistence: persistence)

        let entry1 = makeEntry(path: "/project/a")
        let entry2 = makeEntry(path: "/project/b", permission: .readOnly)
        try await store.save(entry1)
        try await store.save(entry2)

        let store2 = DiskBookmarkStore(fileURL: fileURL, persistence: persistence)
        let loaded = await store2.allEntries()
        #expect(loaded.count == 2)

        let urls = Set(loaded.map(\.url))
        #expect(urls.contains(entry1.url))
        #expect(urls.contains(entry2.url))
    }

    @Test func startsEmptyWhenFileDoesNotExist() async {
        let persistence = MockBookmarkPersistence()
        let fileURL = URL(fileURLWithPath: "/tmp/nonexistent.json")
        let store = DiskBookmarkStore(fileURL: fileURL, persistence: persistence)

        let entries = await store.allEntries()
        #expect(entries.isEmpty)
    }

    @Test func removeDeletesEntryAndPersists() async throws {
        let persistence = MockBookmarkPersistence()
        let fileURL = URL(fileURLWithPath: "/tmp/bookmarks.json")
        let store = DiskBookmarkStore(fileURL: fileURL, persistence: persistence)

        let entry = makeEntry(path: "/project/src")
        try await store.save(entry)
        await store.remove(for: entry.url)

        let remaining = await store.allEntries()
        #expect(remaining.isEmpty)

        // Verify persisted state is also empty
        let store2 = DiskBookmarkStore(fileURL: fileURL, persistence: persistence)
        let loaded = await store2.allEntries()
        #expect(loaded.isEmpty)
    }

    @Test func overwriteExistingURLKeepsLatest() async throws {
        let persistence = MockBookmarkPersistence()
        let fileURL = URL(fileURLWithPath: "/tmp/bookmarks.json")
        let store = DiskBookmarkStore(fileURL: fileURL, persistence: persistence)

        let url = URL(fileURLWithPath: "/project/src")
        let first = BookmarkEntry(
            url: url,
            bookmarkData: Data([0x01]),
            permission: .readOnly
        )
        let second = BookmarkEntry(
            url: url,
            bookmarkData: Data([0x02]),
            permission: .readWrite
        )

        try await store.save(first)
        try await store.save(second)

        let entries = await store.allEntries()
        #expect(entries.count == 1)
        #expect(entries[0].permission == .readWrite)
        #expect(entries[0].bookmarkData == Data([0x02]))
    }

    @Test func reloadBeforeReadReReadsFromDisk() async throws {
        let persistence = MockBookmarkPersistence()
        let fileURL = URL(fileURLWithPath: "/tmp/bookmarks.json")

        // Store 1 writes an entry
        let store1 = DiskBookmarkStore(fileURL: fileURL, persistence: persistence)
        try await store1.save(makeEntry(path: "/project/a"))

        // Store 2 with reloadBeforeRead sees it without being restarted
        let store2 = DiskBookmarkStore(
            fileURL: fileURL,
            persistence: persistence,
            reloadBeforeRead: true
        )
        let entries = await store2.allEntries()
        #expect(entries.count == 1)
        #expect(entries[0].url.path == "/project/a")
    }

    @Test func saveFailurePropagatesError() async {
        let persistence = MockBookmarkPersistence()
        persistence.shouldFailOnWrite = true
        let fileURL = URL(fileURLWithPath: "/tmp/bookmarks.json")
        let store = DiskBookmarkStore(fileURL: fileURL, persistence: persistence)

        await #expect(throws: BookmarkStoreError.self) {
            try await store.save(makeEntry(path: "/project/src"))
        }
    }
}
