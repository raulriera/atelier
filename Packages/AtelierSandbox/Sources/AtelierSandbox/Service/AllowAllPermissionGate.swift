/// No-op permission gate that permits every request unconditionally.
///
/// Used as the default in `SandboxServiceHandler` so existing callers
/// continue to work without change. Mirrors the `NullAuditLogger` pattern.
public struct AllowAllPermissionGate: PermissionGating {
    public init() {}

    public func validate(_ request: SandboxRequest) async throws {}
}
