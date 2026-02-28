import Foundation

/// Errors that can occur during safe file operations.
public enum FileOperationError: Error, Sendable {
    case fileNotFound(URL)
    case permissionDenied(URL)
    case trashFailed(URL, underlying: String)
    case moveFailed(from: URL, to: URL, underlying: String)
    case copyFailed(from: URL, to: URL, underlying: String)
    case renameFailed(URL, newName: String, underlying: String)
    case destinationExists(URL)
}
