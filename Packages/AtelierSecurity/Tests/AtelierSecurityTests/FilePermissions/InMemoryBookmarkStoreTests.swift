import Foundation
import Testing
@testable import AtelierSecurity

@Suite("InMemoryBookmarkStore")
struct InMemoryBookmarkStoreTests {

    @Test func savesAndRetrieves() async {
        let store = InMemoryBookmarkStore()
        let url = URL(fileURLWithPath: "/tmp/bookmark-test")
        let entry = BookmarkEntry(
            url: url,
            bookmarkData: Data([0xAA]),
            permission: .readWrite
        )

        await store.save(entry)
        let retrieved = await store.entry(for: url)

        #expect(retrieved != nil)
        #expect(retrieved?.permission == .readWrite)
    }

    @Test func returnsNilForMissingURL() async {
        let store = InMemoryBookmarkStore()
        let result = await store.entry(for: URL(fileURLWithPath: "/nonexistent"))
        #expect(result == nil)
    }

    @Test func removesEntry() async {
        let store = InMemoryBookmarkStore()
        let url = URL(fileURLWithPath: "/tmp/to-remove")
        let entry = BookmarkEntry(url: url, bookmarkData: Data(), permission: .readOnly)

        await store.save(entry)
        await store.remove(for: url)

        let result = await store.entry(for: url)
        #expect(result == nil)
    }

    @Test func listsAllEntries() async {
        let store = InMemoryBookmarkStore()
        let urlA = URL(fileURLWithPath: "/tmp/a")
        let urlB = URL(fileURLWithPath: "/tmp/b")

        await store.save(BookmarkEntry(url: urlA, bookmarkData: Data(), permission: .readOnly))
        await store.save(BookmarkEntry(url: urlB, bookmarkData: Data(), permission: .readWrite))

        let all = await store.allEntries()
        #expect(all.count == 2)
    }
}
