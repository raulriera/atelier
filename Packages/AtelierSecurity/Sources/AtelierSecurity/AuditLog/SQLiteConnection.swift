import Foundation

/// Abstracts SQLite database operations for testability.
public protocol SQLiteConnection: Sendable {
    /// Opens a database at the given path. Use ":memory:" for in-memory databases.
    func open(path: String) throws

    /// Closes the database connection.
    func close()

    /// Executes a SQL statement that does not return rows.
    func execute(sql: String, parameters: [SQLiteValue]) throws

    /// Queries the database and returns matching rows.
    func query(sql: String, parameters: [SQLiteValue]) throws -> [[String: SQLiteValue]]
}

/// A value that can be stored in or retrieved from a SQLite column.
public enum SQLiteValue: Sendable, Equatable {
    case text(String)
    case real(Double)
    case integer(Int64)
    case null
}
