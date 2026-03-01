/// Validates whether a sandbox request is permitted before dispatch.
///
/// Conformances range from `AllowAllPermissionGate` (no-op) to
/// `ScopedPermissionGate` (path-prefix checks with audit logging).
/// Throws `SandboxError.permissionDenied` on denial.
public protocol PermissionGating: Sendable {
    func validate(_ request: SandboxRequest) async throws
}
