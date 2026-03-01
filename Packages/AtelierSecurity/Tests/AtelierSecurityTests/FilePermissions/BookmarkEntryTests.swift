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

    // MARK: - Codable round-trip

    @Test func roundTripsThroughJSON() throws {
        let original = BookmarkEntry(
            url: URL(fileURLWithPath: "/tmp/test"),
            bookmarkData: Data([0xDE, 0xAD]),
            permission: .readWrite,
            lastAccessedAt: Date(timeIntervalSince1970: 1_000_000),
            isStale: false
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BookmarkEntry.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.url == original.url)
        #expect(decoded.bookmarkData == original.bookmarkData)
        #expect(decoded.permission == original.permission)
        #expect(decoded.isStale == original.isStale)
        #expect(decoded.lastAccessedAt == original.lastAccessedAt)
    }

    @Test func roundTripsWithNilLastAccessedAt() throws {
        let original = BookmarkEntry(
            url: URL(fileURLWithPath: "/tmp/nil-access"),
            bookmarkData: Data(),
            permission: .readOnly
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BookmarkEntry.self, from: data)

        #expect(decoded.lastAccessedAt == nil)
        #expect(decoded.url == original.url)
    }

    @Test func roundTripsStaleEntry() throws {
        let original = BookmarkEntry(
            url: URL(fileURLWithPath: "/tmp/stale-round-trip"),
            bookmarkData: Data([0xFF]),
            permission: .readOnly,
            isStale: true
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BookmarkEntry.self, from: data)

        #expect(decoded.isStale == true)
        #expect(decoded.permission == .readOnly)
    }
}
