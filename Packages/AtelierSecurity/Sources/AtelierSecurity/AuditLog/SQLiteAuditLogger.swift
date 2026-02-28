import Foundation

/// Persistent audit logger backed by a SQLite database.
///
/// Drop-in replacement for `InMemoryAuditLogger`, conforming to the same
/// `AuditLogger` protocol. Events are persisted to an `audit_events` table.
public actor SQLiteAuditLogger: AuditLogger {
    private let connection: SQLiteConnection

    /// Creates a new SQLite audit logger.
    ///
    /// - Parameters:
    ///   - connection: The SQLite connection to use.
    ///   - path: Database file path. Use `":memory:"` for in-memory databases.
    public init(connection: SQLiteConnection, path: String) throws {
        self.connection = connection
        try connection.open(path: path)
        try createSchema()
    }

    public func log(_ event: AuditEvent) {
        do {
            try connection.execute(
                sql: "INSERT INTO audit_events (id, timestamp, category, action, subject, detail) VALUES (?, ?, ?, ?, ?, ?)",
                parameters: [
                    .text(event.id.uuidString),
                    .real(event.timestamp.timeIntervalSince1970),
                    .text(event.category.rawValue),
                    .text(event.action),
                    .text(event.subject),
                    event.detail.map { .text($0) } ?? .null,
                ]
            )
        } catch {
            // Audit logging should not throw — silently drop on failure.
            // In production, this would be surfaced via a health check.
        }
    }

    public func events(
        category: AuditEvent.Category?,
        since: Date?,
        limit: Int?
    ) -> [AuditEvent] {
        var sql = "SELECT id, timestamp, category, action, subject, detail FROM audit_events"
        var conditions: [String] = []
        var parameters: [SQLiteValue] = []

        if let category {
            conditions.append("category = ?")
            parameters.append(.text(category.rawValue))
        }
        if let since {
            conditions.append("timestamp >= ?")
            parameters.append(.real(since.timeIntervalSince1970))
        }

        if !conditions.isEmpty {
            sql += " WHERE " + conditions.joined(separator: " AND ")
        }

        sql += " ORDER BY timestamp ASC"

        if let limit {
            sql += " LIMIT ?"
            parameters.append(.integer(Int64(limit)))
        }

        do {
            let rows = try connection.query(sql: sql, parameters: parameters)
            return rows.compactMap { row in
                guard
                    case .text(let idString) = row["id"],
                    let id = UUID(uuidString: idString),
                    case .real(let timestamp) = row["timestamp"],
                    case .text(let categoryRaw) = row["category"],
                    let cat = AuditEvent.Category(rawValue: categoryRaw),
                    case .text(let action) = row["action"],
                    case .text(let subject) = row["subject"]
                else {
                    return nil
                }

                let detail: String?
                if case .text(let d) = row["detail"] {
                    detail = d
                } else {
                    detail = nil
                }

                return AuditEvent(
                    id: id,
                    timestamp: Date(timeIntervalSince1970: timestamp),
                    category: cat,
                    action: action,
                    subject: subject,
                    detail: detail
                )
            }
        } catch {
            return []
        }
    }

    private nonisolated func createSchema() throws {
        do {
            try connection.execute(
                sql: """
                    CREATE TABLE IF NOT EXISTS audit_events (
                        id TEXT PRIMARY KEY,
                        timestamp REAL NOT NULL,
                        category TEXT NOT NULL,
                        action TEXT NOT NULL,
                        subject TEXT NOT NULL,
                        detail TEXT
                    )
                    """,
                parameters: []
            )
            try connection.execute(
                sql: "CREATE INDEX IF NOT EXISTS idx_audit_category ON audit_events(category)",
                parameters: []
            )
            try connection.execute(
                sql: "CREATE INDEX IF NOT EXISTS idx_audit_timestamp ON audit_events(timestamp)",
                parameters: []
            )
        } catch {
            throw AuditLogError.migrationFailed(underlying: "\(error)")
        }
    }
}
