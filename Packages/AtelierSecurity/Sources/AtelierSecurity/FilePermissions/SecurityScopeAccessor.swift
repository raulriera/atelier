import Foundation

/// Abstracts security-scoped resource access for testability.
public protocol SecurityScopeAccessor: Sendable {
    func startAccessing(_ url: URL) -> Bool
    func stopAccessing(_ url: URL)
}

/// Uses the real `URL.startAccessingSecurityScopedResource()` system API.
public struct SystemSecurityScopeAccessor: SecurityScopeAccessor {
    public init() {}

    public func startAccessing(_ url: URL) -> Bool {
        url.startAccessingSecurityScopedResource()
    }

    public func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}
