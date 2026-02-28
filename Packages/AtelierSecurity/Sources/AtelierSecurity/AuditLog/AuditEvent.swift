import Foundation

/// A single audit log entry recording a security-relevant action.
public struct AuditEvent: Sendable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let category: Category
    public let action: String
    public let subject: String
    public let detail: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        category: Category,
        action: String,
        subject: String,
        detail: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.action = action
        self.subject = subject
        self.detail = detail
    }
}

extension AuditEvent {
    public enum Category: String, Sendable {
        case filePermission
        case fileOperation
        case networkPolicy
        case credentialAccess
        case snapshot
    }
}
