import Foundation

/// Errors that can occur during disk-backed bookmark store operations.
public enum BookmarkStoreError: Error, Sendable {
    case writeFailed(path: String, underlying: String)
    case readFailed(path: String, underlying: String)
}
