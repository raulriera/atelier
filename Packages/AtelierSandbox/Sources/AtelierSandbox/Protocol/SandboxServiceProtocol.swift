import Foundation

/// Swift-native async protocol for sandbox file operations.
///
/// Both `SandboxClient` (app side) and test mocks conform to this,
/// providing a type-safe API independent of the XPC transport.
public protocol SandboxServiceProtocol: Sendable {
    func readFile(at path: String) async throws -> Data
    func writeFile(data: Data, to path: String) async throws
    func moveFile(from source: String, to destination: String) async throws
    func copyFile(from source: String, to destination: String) async throws
    func trashFile(at path: String) async throws
    func listDirectory(at path: String) async throws -> DirectoryListing
    func fileMetadata(at path: String) async throws -> FileMetadata
}
