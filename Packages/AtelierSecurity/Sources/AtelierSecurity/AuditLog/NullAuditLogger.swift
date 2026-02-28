import Foundation

/// No-op audit logger for contexts where auditing is not needed.
public struct NullAuditLogger: AuditLogger {
    public init() {}

    public func log(_ event: AuditEvent) {}

    public func events(
        category: AuditEvent.Category?,
        since: Date?,
        limit: Int?
    ) -> [AuditEvent] {
        []
    }
}
