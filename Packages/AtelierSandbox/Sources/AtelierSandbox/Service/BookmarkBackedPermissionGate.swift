import AtelierSecurity

/// Permission gate that dynamically queries a `BookmarkStore` for granted scopes.
///
/// On every `validate` call, reads fresh entries from the store and delegates
/// path-matching and audit logging to `ScopedPermissionGate`. This means
/// grants and revokes are reflected immediately without restart.
public struct BookmarkBackedPermissionGate: PermissionGating {
    private let store: BookmarkStore
    private let auditLogger: AuditLogger

    public init(store: BookmarkStore, auditLogger: AuditLogger = NullAuditLogger()) {
        self.store = store
        self.auditLogger = auditLogger
    }

    public func validate(_ request: SandboxRequest) async throws {
        let entries = await store.allEntries()
        let scopes = entries
            .filter { !$0.isStale }
            .map { ScopedPermissionGate.Scope(path: $0.url.path, permission: $0.permission) }
        let gate = ScopedPermissionGate(scopes: scopes, auditLogger: auditLogger)
        try await gate.validate(request)
    }
}
