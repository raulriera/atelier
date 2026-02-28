/// Errors that can occur during SQLite-backed audit logging.
public enum AuditLogError: Error, Sendable {
    case databaseOpenFailed(underlying: String)
    case queryFailed(underlying: String)
    case migrationFailed(underlying: String)
}
