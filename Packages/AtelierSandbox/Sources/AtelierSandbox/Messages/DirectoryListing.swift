import Foundation

/// A directory listing returned by the sandbox service.
public struct DirectoryListing: Codable, Sendable, Equatable {
    public let path: String
    public let entries: [Entry]

    public init(path: String, entries: [Entry]) {
        self.path = path
        self.entries = entries
    }

    /// A single entry in a directory listing.
    public struct Entry: Codable, Sendable, Equatable {
        public let name: String
        public let isDirectory: Bool

        public init(name: String, isDirectory: Bool) {
            self.name = name
            self.isDirectory = isDirectory
        }
    }
}
