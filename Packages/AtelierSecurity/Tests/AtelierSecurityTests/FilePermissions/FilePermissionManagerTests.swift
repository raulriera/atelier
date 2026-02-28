import Foundation
import Testing
@testable import AtelierSecurity

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
    var shouldGrantAccess = true

    func startAccessing(_ url: URL) -> Bool {
        shouldGrantAccess
    }

    func stopAccessing(_ url: URL) {}
}

@Suite("FilePermissionManager")
struct FilePermissionManagerTests {

    @Test func grantCreatesBookmarkAndStores() async throws {
        let store = InMemoryBookmarkStore()
        let logger = InMemoryAuditLogger()
        let manager = FilePermissionManager(
            store: store,
            bookmarkCreator: MockBookmarkCreator(),
            accessor: MockSecurityScopeAccessor(),
            auditLogger: logger
        )

        let url = URL(fileURLWithPath: "/tmp/grant-test")
        let entry = try await manager.grant(url: url, permission: .readOnly)

        #expect(entry.url == url)
        #expect(entry.permission == .readOnly)

        let stored = await store.entry(for: url)
        #expect(stored != nil)

        let events = await logger.events(category: .filePermission, since: nil, limit: nil)
        #expect(events.count == 1)
        #expect(events[0].action == "grant")
    }

    @Test func grantThrowsOnBookmarkFailure() async {
        let manager = FilePermissionManager(
            store: InMemoryBookmarkStore(),
            bookmarkCreator: MockBookmarkCreator(shouldFail: true),
            accessor: MockSecurityScopeAccessor()
        )

        let url = URL(fileURLWithPath: "/tmp/fail-test")
        await #expect(throws: FilePermissionError.self) {
            try await manager.grant(url: url, permission: .readWrite)
        }
    }

    @Test func fullLifecycle_grantAccessRelinquishRevoke() async throws {
        let store = InMemoryBookmarkStore()
        let logger = InMemoryAuditLogger()
        let manager = FilePermissionManager(
            store: store,
            bookmarkCreator: MockBookmarkCreator(),
            accessor: MockSecurityScopeAccessor(shouldGrantAccess: true),
            auditLogger: logger
        )

        let url = URL(fileURLWithPath: "/tmp/lifecycle-test")

        // Grant
        try await manager.grant(url: url, permission: .readWrite)

        // Access
        let handle = try await manager.access(url: url)
        #expect(handle.hasAccess == true)
        #expect(handle.permission == .readWrite)

        // Relinquish
        await manager.relinquish(handle)

        // Revoke
        await manager.revoke(url: url)
        let stored = await store.entry(for: url)
        #expect(stored == nil)

        // Verify audit trail: grant, access, relinquish, revoke
        let events = await logger.events(category: .filePermission, since: nil, limit: nil)
        #expect(events.count == 4)
        #expect(events.map(\.action) == ["grant", "access", "relinquish", "revoke"])
    }

    @Test func accessThrowsWhenNoBookmark() async {
        let manager = FilePermissionManager(
            store: InMemoryBookmarkStore(),
            bookmarkCreator: MockBookmarkCreator(),
            accessor: MockSecurityScopeAccessor()
        )

        await #expect(throws: FilePermissionError.self) {
            _ = try await manager.access(url: URL(fileURLWithPath: "/tmp/no-bookmark"))
        }
    }

    @Test func accessThrowsWhenStaleBookmark() async throws {
        let store = InMemoryBookmarkStore()
        let url = URL(fileURLWithPath: "/tmp/stale-test")
        let staleEntry = BookmarkEntry(
            url: url,
            bookmarkData: Data(),
            permission: .readOnly,
            isStale: true
        )
        await store.save(staleEntry)

        let manager = FilePermissionManager(
            store: store,
            bookmarkCreator: MockBookmarkCreator(),
            accessor: MockSecurityScopeAccessor()
        )

        await #expect(throws: FilePermissionError.self) {
            _ = try await manager.access(url: url)
        }
    }

    @Test func accessThrowsWhenScopeAccessDenied() async throws {
        let store = InMemoryBookmarkStore()
        let manager = FilePermissionManager(
            store: store,
            bookmarkCreator: MockBookmarkCreator(),
            accessor: MockSecurityScopeAccessor(shouldGrantAccess: false)
        )

        let url = URL(fileURLWithPath: "/tmp/denied-test")
        try await manager.grant(url: url, permission: .readOnly)

        await #expect(throws: FilePermissionError.self) {
            _ = try await manager.access(url: url)
        }
    }
}
