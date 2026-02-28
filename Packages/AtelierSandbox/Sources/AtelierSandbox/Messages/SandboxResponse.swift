import Foundation

/// A response sent from the sandbox XPC service back to the client.
///
/// Each case carries the result data for the corresponding request.
public enum SandboxResponse: Codable, Sendable {
    case data(Data)
    case empty
    case listing(DirectoryListing)
    case metadata(FileMetadata)
}
