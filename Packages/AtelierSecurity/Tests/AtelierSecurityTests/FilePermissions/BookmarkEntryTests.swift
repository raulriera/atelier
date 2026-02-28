import Foundation
import Testing
@testable import AtelierSecurity

@Suite("BookmarkEntry")
struct BookmarkEntryTests {

    @Test func initializesWithDefaults() {
        let url = URL(fileURLWithPath: "/tmp/test")
        let entry = BookmarkEntry(
            url: url,
            bookmarkData: Data([0x01, 0x02]),
            permission: .readOnly
        )

        #expect(entry.url == url)
        #expect(entry.permission == .readOnly)
        #expect(entry.isStale == false)
        #expect(entry.lastAccessedAt == nil)
    }

    @Test func staleEntryIsMarked() {
        let entry = BookmarkEntry(
            url: URL(fileURLWithPath: "/tmp/stale"),
            bookmarkData: Data(),
            permission: .readWrite,
            isStale: true
        )

        #expect(entry.isStale == true)
    }
}
