import Foundation

/// Orchestrates file permission lifecycle: grant, access, relinquish, revoke.
public final class FilePermissionManager: Sendable {
    private let store: BookmarkStore
    private let bookmarkCreator: BookmarkCreator
    private let accessor: SecurityScopeAccessor
    private let auditLogger: AuditLogger

    public init(
        store: BookmarkStore,
        bookmarkCreator: BookmarkCreator = SystemBookmarkCreator(),
        accessor: SecurityScopeAccessor = SystemSecurityScopeAccessor(),
        auditLogger: AuditLogger = NullAuditLogger()
    ) {
        self.store = store
        self.bookmarkCreator = bookmarkCreator
        self.accessor = accessor
        self.auditLogger = auditLogger
    }

    /// Grants file access by creating a security-scoped bookmark.
    ///
    /// - Parameters:
    ///   - url: The file or directory URL to bookmark.
    ///   - permission: The level of access to grant.
    /// - Returns: The created bookmark entry.
    @discardableResult
    public func grant(url: URL, permission: FilePermission) async throws -> BookmarkEntry {
        let data: Data
        do {
            data = try bookmarkCreator.createBookmarkData(
                for: url,
                readOnly: permission == .readOnly
            )
        } catch {
            throw FilePermissionError.bookmarkCreationFailed(url, underlying: error)
        }

        let entry = BookmarkEntry(
            url: url,
            bookmarkData: data,
            permission: permission
        )
        try await store.save(entry)

        await auditLogger.log(AuditEvent(
            category: .filePermission,
            action: "grant",
            subject: url.path,
            detail: permission.rawValue
        ))

        return entry
    }

    /// Begins security-scoped access for a previously bookmarked URL.
    ///
    /// - Parameter url: The bookmarked URL to access.
    /// - Returns: A `FileAccess` handle that must be relinquished when done.
    public func access(url: URL) async throws -> FileAccess {
        guard let entry = await store.entry(for: url) else {
            throw FilePermissionError.noBookmarkFound(url)
        }
        if entry.isStale {
            throw FilePermissionError.bookmarkStale(url)
        }

        let handle = FileAccess(
            url: entry.url,
            permission: entry.permission,
            accessor: accessor
        )

        guard handle.hasAccess else {
            throw FilePermissionError.accessDenied(url)
        }

        await auditLogger.log(AuditEvent(
            category: .filePermission,
            action: "access",
            subject: url.path
        ))

        return handle
    }

    /// Relinquishes an active file access handle.
    public func relinquish(_ handle: FileAccess) async {
        handle.relinquish()

        await auditLogger.log(AuditEvent(
            category: .filePermission,
            action: "relinquish",
            subject: handle.url.path
        ))
    }

    /// Revokes all access for a URL by removing its bookmark.
    public func revoke(url: URL) async {
        await store.remove(for: url)

        await auditLogger.log(AuditEvent(
            category: .filePermission,
            action: "revoke",
            subject: url.path
        ))
    }
}
