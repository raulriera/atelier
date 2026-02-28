import Foundation

/// Errors that can occur during coordinated file operations.
public enum CoordinatedFileError: Error, Sendable {
    case coordinationFailed(underlying: String)
    case readFailed(URL, underlying: String)
    case writeFailed(URL, underlying: String)
    case moveFailed(from: URL, to: URL, underlying: String)
}
