import AtelierSecurity

/// Permission gate that validates requests against user-granted path scopes.
///
/// Each scope pairs a directory path with a `FilePermission` level (`.readOnly`
/// or `.readWrite`). The most-specific scope (longest matching prefix) determines
/// the permission for a given path. All affected paths in a request must pass.
///
/// Denials and approvals are logged via `AuditLogger` under `.filePermission`.
public struct ScopedPermissionGate: PermissionGating {
    /// A single user-granted access scope.
    public struct Scope: Sendable {
        public let path: String
        public let permission: FilePermission

        public init(path: String, permission: FilePermission) {
            self.path = path
            self.permission = permission
        }
    }

    private let scopes: [Scope]
    private let auditLogger: AuditLogger

    public init(scopes: [Scope], auditLogger: AuditLogger = NullAuditLogger()) {
        self.scopes = scopes
        self.auditLogger = auditLogger
    }

    public func validate(_ request: SandboxRequest) async throws {
        let requiredScope = request.requiredScope

        for path in request.affectedPaths {
            guard let matchingScope = bestMatchingScope(for: path) else {
                await logDenial(path: path, reason: "no matching scope")
                throw SandboxError.permissionDenied(path)
            }

            if requiredScope == .write && matchingScope.permission == .readOnly {
                await logDenial(
                    path: path,
                    reason: "write denied in readOnly scope \(matchingScope.path)"
                )
                throw SandboxError.permissionDenied(path)
            }

            await logApproval(path: path, scope: matchingScope)
        }
    }

    /// Returns the scope with the longest matching path prefix, or `nil`.
    private func bestMatchingScope(for path: String) -> Scope? {
        scopes
            .filter { pathIsWithinScope(path, scopePath: $0.path) }
            .max { $0.path.count < $1.path.count }
    }

    /// Checks whether `path` falls within `scopePath` using trailing-slash
    /// normalization to prevent `/tmp/evil` from matching scope `/tmp/e`.
    private func pathIsWithinScope(_ path: String, scopePath: String) -> Bool {
        let normalizedScope = scopePath.hasSuffix("/") ? scopePath : scopePath + "/"
        let normalizedPath = path.hasSuffix("/") ? path : path + "/"
        return normalizedPath.hasPrefix(normalizedScope) || path == scopePath
    }

    private func logDenial(path: String, reason: String) async {
        await auditLogger.log(AuditEvent(
            category: .filePermission,
            action: "denied",
            subject: path,
            detail: reason
        ))
    }

    private func logApproval(path: String, scope: Scope) async {
        await auditLogger.log(AuditEvent(
            category: .filePermission,
            action: "approved",
            subject: path,
            detail: "matched scope \(scope.path) (\(scope.permission.rawValue))"
        ))
    }
}
