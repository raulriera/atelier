import Foundation
import Testing
@testable import AtelierSandbox
@testable import AtelierSecurity

// MARK: - Test Audit Logger

private actor SpyAuditLogger: AuditLogger {
    private(set) var logged: [AuditEvent] = []

    func log(_ event: AuditEvent) {
        logged.append(event)
    }

    func events(
        category: AuditEvent.Category?,
        since: Date?,
        limit: Int?
    ) -> [AuditEvent] {
        logged
    }
}

@Suite("BookmarkBackedPermissionGate")
struct BookmarkBackedPermissionGateTests {

    private func makeEntry(
        path: String,
        permission: FilePermission = .readWrite,
        isStale: Bool = false
    ) -> BookmarkEntry {
        BookmarkEntry(
            url: URL(fileURLWithPath: path),
            bookmarkData: Data([0x01]),
            permission: permission,
            isStale: isStale
        )
    }

    // MARK: - Allow cases

    @Test func allowsReadWithMatchingBookmark() async throws {
        let store = InMemoryBookmarkStore()
        await store.save(makeEntry(path: "/project", permission: .readOnly))
        let gate = BookmarkBackedPermissionGate(store: store)

        try await gate.validate(.readFile(path: "/project/file.txt"))
    }

    @Test func allowsWriteWithReadWriteBookmark() async throws {
        let store = InMemoryBookmarkStore()
        await store.save(makeEntry(path: "/project", permission: .readWrite))
        let gate = BookmarkBackedPermissionGate(store: store)

        try await gate.validate(.writeFile(data: Data(), path: "/project/file.txt"))
    }

    // MARK: - Deny cases

    @Test func deniesWhenNoBookmarks() async {
        let store = InMemoryBookmarkStore()
        let gate = BookmarkBackedPermissionGate(store: store)

        await #expect(throws: SandboxError.self) {
            try await gate.validate(.readFile(path: "/project/file.txt"))
        }
    }

    @Test func deniesWhenOutsideScope() async {
        let store = InMemoryBookmarkStore()
        await store.save(makeEntry(path: "/project"))
        let gate = BookmarkBackedPermissionGate(store: store)

        await #expect(throws: SandboxError.self) {
            try await gate.validate(.readFile(path: "/etc/passwd"))
        }
    }

    @Test func deniesWriteInReadOnlyBookmark() async {
        let store = InMemoryBookmarkStore()
        await store.save(makeEntry(path: "/project", permission: .readOnly))
        let gate = BookmarkBackedPermissionGate(store: store)

        await #expect(throws: SandboxError.self) {
            try await gate.validate(.writeFile(data: Data(), path: "/project/file.txt"))
        }
    }

    // MARK: - Stale filtering

    @Test func filtersStaleBookmarks() async {
        let store = InMemoryBookmarkStore()
        await store.save(makeEntry(path: "/project", isStale: true))
        let gate = BookmarkBackedPermissionGate(store: store)

        await #expect(throws: SandboxError.self) {
            try await gate.validate(.readFile(path: "/project/file.txt"))
        }
    }

    // MARK: - Dynamic updates

    @Test func reflectsRevokeImmediately() async throws {
        let store = InMemoryBookmarkStore()
        let entry = makeEntry(path: "/project")
        await store.save(entry)
        let gate = BookmarkBackedPermissionGate(store: store)

        // Access works initially
        try await gate.validate(.readFile(path: "/project/file.txt"))

        // Revoke the bookmark
        await store.remove(for: entry.url)

        // Now denied
        await #expect(throws: SandboxError.self) {
            try await gate.validate(.readFile(path: "/project/file.txt"))
        }
    }

    @Test func reflectsNewGrantImmediately() async throws {
        let store = InMemoryBookmarkStore()
        let gate = BookmarkBackedPermissionGate(store: store)

        // Initially denied
        await #expect(throws: SandboxError.self) {
            try await gate.validate(.readFile(path: "/project/file.txt"))
        }

        // Grant access
        await store.save(makeEntry(path: "/project"))

        // Now allowed
        try await gate.validate(.readFile(path: "/project/file.txt"))
    }

    // MARK: - Most-specific scope

    @Test func mostSpecificBookmarkWins() async throws {
        let store = InMemoryBookmarkStore()
        await store.save(makeEntry(path: "/project", permission: .readWrite))
        await store.save(makeEntry(path: "/project/readonly-dir", permission: .readOnly))
        let gate = BookmarkBackedPermissionGate(store: store)

        // Write to /project works
        try await gate.validate(.writeFile(data: Data(), path: "/project/file.txt"))

        // Write to more-specific readOnly sub-scope is denied
        await #expect(throws: SandboxError.self) {
            try await gate.validate(
                .writeFile(data: Data(), path: "/project/readonly-dir/file.txt")
            )
        }
    }

    // MARK: - Audit logging

    @Test func logsApprovalAndDenial() async throws {
        let logger = SpyAuditLogger()
        let store = InMemoryBookmarkStore()
        await store.save(makeEntry(path: "/project", permission: .readOnly))
        let gate = BookmarkBackedPermissionGate(store: store, auditLogger: logger)

        // Approval
        try await gate.validate(.readFile(path: "/project/file.txt"))

        // Denial
        _ = try? await gate.validate(
            .writeFile(data: Data(), path: "/project/file.txt")
        )

        let events = await logger.events(category: nil, since: nil, limit: nil)
        #expect(events.count == 2)
        #expect(events[0].action == "approved")
        #expect(events[1].action == "denied")
    }
}
