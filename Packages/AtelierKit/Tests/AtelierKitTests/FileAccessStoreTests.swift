import Foundation
import Testing
@testable import AtelierKit
import AtelierSecurity

// MARK: - Mocks

private struct MockBookmarkCreator: BookmarkCreator {
    var shouldFail = false

    func createBookmarkData(for url: URL, readOnly: Bool) throws -> Data {
        if shouldFail {
            throw NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "mock failure"])
        }
        return Data("mock-bookmark-\(url.path)".utf8)
    }
}

private struct MockSecurityScopeAccessor: SecurityScopeAccessor {
    func startAccessing(_ url: URL) -> Bool { true }
    func stopAccessing(_ url: URL) {}
}

// MARK: - Tests

@Suite("FileAccessStore")
struct FileAccessStoreTests {

    private func makeStore(
        bookmarkStore: BookmarkStore = InMemoryBookmarkStore(),
        shouldFail: Bool = false
    ) -> FileAccessStore {
        let manager = FilePermissionManager(
            store: bookmarkStore,
            bookmarkCreator: MockBookmarkCreator(shouldFail: shouldFail),
            accessor: MockSecurityScopeAccessor()
        )
        return FileAccessStore(permissionManager: manager, store: bookmarkStore)
    }

    @Test @MainActor func grantAddsEntryAndReloads() async throws {
        let store = makeStore()
        let url = URL(fileURLWithPath: "/tmp/grant-test")

        await store.grant(url: url)

        #expect(store.entries.count == 1)
        #expect(store.entries[0].url == url)
        #expect(store.error == nil)
    }

    @Test @MainActor func revokeRemovesEntry() async throws {
        let store = makeStore()
        let url = URL(fileURLWithPath: "/tmp/revoke-test")

        await store.grant(url: url)
        #expect(store.entries.count == 1)

        await store.revoke(url: url)
        #expect(store.entries.isEmpty)
    }

    @Test @MainActor func grantSetsErrorOnFailure() async {
        let store = makeStore(shouldFail: true)
        let url = URL(fileURLWithPath: "/tmp/fail-test")

        await store.grant(url: url)

        #expect(store.error != nil)
        #expect(store.entries.isEmpty)
    }

    @Test @MainActor func loadPopulatesFromStore() async throws {
        let bookmarkStore = InMemoryBookmarkStore()
        let entry = BookmarkEntry(
            url: URL(fileURLWithPath: "/tmp/existing"),
            bookmarkData: Data("data".utf8),
            permission: .readWrite
        )
        await bookmarkStore.save(entry)

        let store = makeStore(bookmarkStore: bookmarkStore)
        await store.load()

        #expect(store.entries.count == 1)
        #expect(store.entries[0].url == entry.url)
    }

    @Test @MainActor func dismissErrorClearsError() async {
        let store = makeStore(shouldFail: true)
        let url = URL(fileURLWithPath: "/tmp/dismiss-test")

        await store.grant(url: url)
        #expect(store.error != nil)

        store.dismissError()
        #expect(store.error == nil)
    }

    @Test @MainActor func entriesAreSortedByPath() async throws {
        let store = makeStore()

        await store.grant(url: URL(fileURLWithPath: "/tmp/z-folder"))
        await store.grant(url: URL(fileURLWithPath: "/tmp/a-folder"))

        #expect(store.entries.count == 2)
        #expect(store.entries[0].url.lastPathComponent == "a-folder")
        #expect(store.entries[1].url.lastPathComponent == "z-folder")
    }
}
