import Foundation

/// A request sent from the client to the sandbox XPC service.
///
/// Each case maps to one file operation. Encoded to `Data` for XPC transport.
public enum SandboxRequest: Codable, Sendable {
    case readFile(path: String)
    case writeFile(data: Data, path: String)
    case moveFile(source: String, destination: String)
    case copyFile(source: String, destination: String)
    case trashFile(path: String)
    case listDirectory(path: String)
    case fileMetadata(path: String)
}
