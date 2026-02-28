import Foundation
#if canImport(SQLite3)
import SQLite3
#endif

/// Real SQLite connection using the system SQLite3 C API.
public final class SystemSQLiteConnection: SQLiteConnection, @unchecked Sendable {
    private var db: OpaquePointer?

    public init() {}

    deinit {
        close()
    }

    public func open(path: String) throws {
        let result = sqlite3_open(path, &db)
        guard result == SQLITE_OK else {
            let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            throw AuditLogError.databaseOpenFailed(underlying: message)
        }
    }

    public func close() {
        if let db {
            sqlite3_close(db)
            self.db = nil
        }
    }

    public func execute(sql: String, parameters: [SQLiteValue]) throws {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            throw AuditLogError.queryFailed(underlying: message)
        }

        try bind(parameters: parameters, to: stmt!)

        let result = sqlite3_step(stmt)
        guard result == SQLITE_DONE else {
            let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            throw AuditLogError.queryFailed(underlying: message)
        }
    }

    public func query(sql: String, parameters: [SQLiteValue]) throws -> [[String: SQLiteValue]] {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            throw AuditLogError.queryFailed(underlying: message)
        }

        try bind(parameters: parameters, to: stmt!)

        var rows: [[String: SQLiteValue]] = []
        let columnCount = sqlite3_column_count(stmt)

        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String: SQLiteValue] = [:]
            for i in 0..<columnCount {
                let name = String(cString: sqlite3_column_name(stmt, i))
                let type = sqlite3_column_type(stmt, i)
                switch type {
                case SQLITE_TEXT:
                    row[name] = .text(String(cString: sqlite3_column_text(stmt, i)))
                case SQLITE_FLOAT:
                    row[name] = .real(sqlite3_column_double(stmt, i))
                case SQLITE_INTEGER:
                    row[name] = .integer(sqlite3_column_int64(stmt, i))
                default:
                    row[name] = .null
                }
            }
            rows.append(row)
        }

        return rows
    }

    private func bind(parameters: [SQLiteValue], to stmt: OpaquePointer) throws {
        for (index, param) in parameters.enumerated() {
            let position = Int32(index + 1)
            let result: Int32
            switch param {
            case .text(let value):
                result = sqlite3_bind_text(stmt, position, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
            case .real(let value):
                result = sqlite3_bind_double(stmt, position, value)
            case .integer(let value):
                result = sqlite3_bind_int64(stmt, position, value)
            case .null:
                result = sqlite3_bind_null(stmt, position)
            }
            guard result == SQLITE_OK else {
                let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
                throw AuditLogError.queryFailed(underlying: message)
            }
        }
    }
}
