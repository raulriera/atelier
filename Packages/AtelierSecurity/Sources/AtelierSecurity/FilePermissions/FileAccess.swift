import Foundation

/// RAII handle for security-scoped resource access.
///
/// Begins access on creation, ends access on `relinquish()`.
/// Callers must call `relinquish()` when done accessing the resource.
public struct FileAccess: Sendable {
    public let url: URL
    public let permission: FilePermission

    private let accessor: SecurityScopeAccessor
    private let isActive: Bool

    init(
        url: URL,
        permission: FilePermission,
        accessor: SecurityScopeAccessor
    ) {
        self.url = url
        self.permission = permission
        self.accessor = accessor
        self.isActive = accessor.startAccessing(url)
    }

    /// Whether access was successfully started.
    public var hasAccess: Bool { isActive }

    /// Ends security-scoped access to the resource.
    public func relinquish() {
        if isActive {
            accessor.stopAccessing(url)
        }
    }
}
