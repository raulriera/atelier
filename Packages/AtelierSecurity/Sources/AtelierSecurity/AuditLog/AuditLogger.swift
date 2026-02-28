import Foundation

/// Protocol for audit event logging.
///
/// Async interface enables actor conformances for thread-safe implementations.
public protocol AuditLogger: Sendable {
    func log(_ event: AuditEvent) async
    func events(
        category: AuditEvent.Category?,
        since: Date?,
        limit: Int?
    ) async -> [AuditEvent]
}
