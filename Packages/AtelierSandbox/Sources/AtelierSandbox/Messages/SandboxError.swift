import Foundation

/// Error type that crosses the XPC boundary via Codable encoding.
///
/// Maps from underlying `FileOperationError` and `CoordinatedFileError` types
/// into a flat, serializable representation.
public enum SandboxError: Error, Codable, Sendable {
    case fileNotFound(String)
    case permissionDenied(String)
    case operationFailed(String)
    case encodingFailed(String)
    case decodingFailed(String)
    case connectionInterrupted
}
