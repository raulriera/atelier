import Foundation
import Testing
@testable import AtelierSecurity

// MARK: - Mock

private final class MockSQLiteConnection: SQLiteConnection, @unchecked Sendable {
    var rows: [[String: SQLiteValue]] = []
    var executedSQL: [String] = []
    var shouldFailOnExecute = false
    var shouldFailOnQuery = false
    var shouldFailOnOpen = false

    func open(path: String) throws {
        if shouldFailOnOpen {
            throw AuditLogError.databaseOpenFailed(underlying: "mock open failure")
        }
    }

    func close() {}

    func execute(sql: String, parameters: [SQLiteValue]) throws {
        if shouldFailOnExecute {
            throw AuditLogError.queryFailed(underlying: "mock execute failure")
        }
        executedSQL.append(sql)

        // Store INSERT data as queryable rows.
        if sql.hasPrefix("INSERT") {
            var row: [String: SQLiteValue] = [:]
            let columns = ["id", "timestamp", "category", "action", "subject", "detail"]
            for (index, column) in columns.enumerated() where index < parameters.count {
                row[column] = parameters[index]
            }
            rows.append(row)
        }
    }

    func query(sql: String, parameters: [SQLiteValue]) throws -> [[String: SQLiteValue]] {
        if shouldFailOnQuery {
            throw AuditLogError.queryFailed(underlying: "mock query failure")
        }
        executedSQL.append(sql)

        // Apply basic filtering for category parameter.
        var filtered = rows
        if let categoryIndex = parameters.firstIndex(where: { value in
            if case .text = value { return true }
            return false
        }) {
            if case .text(let category) = parameters[categoryIndex] {
                filtered = rows.filter { row in
                    if case .text(let rowCategory) = row["category"] {
                        return rowCategory == category
                    }
                    return false
                }
            }
        }

        return filtered
    }
}

@Suite("SQLiteAuditLogger")
struct SQLiteAuditLoggerTests {

    @Test func createsSchemaOnInit() throws {
        let mock = MockSQLiteConnection()
        _ = try SQLiteAuditLogger(connection: mock, path: ":memory:")

        // Should execute CREATE TABLE and two CREATE INDEX statements.
        #expect(mock.executedSQL.count == 3)
        #expect(mock.executedSQL[0].contains("CREATE TABLE"))
        #expect(mock.executedSQL[1].contains("idx_audit_category"))
        #expect(mock.executedSQL[2].contains("idx_audit_timestamp"))
    }

    @Test func logsAndRetrievesEvents() async throws {
        let mock = MockSQLiteConnection()
        let logger = try SQLiteAuditLogger(connection: mock, path: ":memory:")

        await logger.log(AuditEvent(
            category: .filePermission,
            action: "grant",
            subject: "/path/a"
        ))
        await logger.log(AuditEvent(
            category: .fileOperation,
            action: "trash",
            subject: "/path/b"
        ))

        let all = await logger.events(category: nil, since: nil, limit: nil)
        #expect(all.count == 2)
        #expect(all[0].subject == "/path/a")
        #expect(all[1].subject == "/path/b")
    }

    @Test func filtersByCategory() async throws {
        let mock = MockSQLiteConnection()
        let logger = try SQLiteAuditLogger(connection: mock, path: ":memory:")

        await logger.log(AuditEvent(category: .filePermission, action: "grant", subject: "a"))
        await logger.log(AuditEvent(category: .fileOperation, action: "trash", subject: "b"))
        await logger.log(AuditEvent(category: .filePermission, action: "revoke", subject: "c"))

        let permissions = await logger.events(category: .filePermission, since: nil, limit: nil)
        #expect(permissions.count == 2)
        #expect(permissions[0].subject == "a")
        #expect(permissions[1].subject == "c")
    }

    @Test func handlesNullDetail() async throws {
        let mock = MockSQLiteConnection()
        let logger = try SQLiteAuditLogger(connection: mock, path: ":memory:")

        await logger.log(AuditEvent(
            category: .fileOperation,
            action: "test",
            subject: "no-detail"
        ))

        let events = await logger.events(category: nil, since: nil, limit: nil)
        #expect(events.count == 1)
        #expect(events[0].detail == nil)
    }

    @Test func handlesDetailPresent() async throws {
        let mock = MockSQLiteConnection()
        let logger = try SQLiteAuditLogger(connection: mock, path: ":memory:")

        await logger.log(AuditEvent(
            category: .fileOperation,
            action: "test",
            subject: "with-detail",
            detail: "some detail"
        ))

        let events = await logger.events(category: nil, since: nil, limit: nil)
        #expect(events.count == 1)
        #expect(events[0].detail == "some detail")
    }

    @Test func returnsEmptyOnQueryFailure() async throws {
        let mock = MockSQLiteConnection()
        let logger = try SQLiteAuditLogger(connection: mock, path: ":memory:")

        await logger.log(AuditEvent(category: .fileOperation, action: "test", subject: "x"))
        mock.shouldFailOnQuery = true

        let events = await logger.events(category: nil, since: nil, limit: nil)
        #expect(events.isEmpty)
    }

    @Test func throwsOnOpenFailure() {
        let mock = MockSQLiteConnection()
        mock.shouldFailOnOpen = true

        #expect(throws: AuditLogError.self) {
            try SQLiteAuditLogger(connection: mock, path: ":memory:")
        }
    }

    @Test func worksWithRealSQLiteConnection() async throws {
        let connection = SystemSQLiteConnection()
        let logger = try SQLiteAuditLogger(connection: connection, path: ":memory:")

        await logger.log(AuditEvent(
            category: .filePermission,
            action: "grant",
            subject: "/test/path",
            detail: "read-only"
        ))
        await logger.log(AuditEvent(
            category: .fileOperation,
            action: "trash",
            subject: "/test/file"
        ))

        let all = await logger.events(category: nil, since: nil, limit: nil)
        #expect(all.count == 2)
        #expect(all[0].action == "grant")
        #expect(all[1].action == "trash")

        let permissions = await logger.events(category: .filePermission, since: nil, limit: nil)
        #expect(permissions.count == 1)
        #expect(permissions[0].detail == "read-only")

        let limited = await logger.events(category: nil, since: nil, limit: 1)
        #expect(limited.count == 1)
    }

    @Test func supportsNewAuditCategories() async throws {
        let connection = SystemSQLiteConnection()
        let logger = try SQLiteAuditLogger(connection: connection, path: ":memory:")

        await logger.log(AuditEvent(category: .credentialAccess, action: "store", subject: "api-key"))
        await logger.log(AuditEvent(category: .snapshot, action: "create", subject: "snap-1"))

        let credentials = await logger.events(category: .credentialAccess, since: nil, limit: nil)
        #expect(credentials.count == 1)
        #expect(credentials[0].action == "store")

        let snapshots = await logger.events(category: .snapshot, since: nil, limit: nil)
        #expect(snapshots.count == 1)
        #expect(snapshots[0].action == "create")
    }
}
