import Foundation

/// File metadata returned by the sandbox service.
public struct FileMetadata: Codable, Sendable, Equatable {
    public let path: String
    public let size: UInt64
    public let creationDate: Date?
    public let modificationDate: Date?
    public let isDirectory: Bool
    public let isReadable: Bool
    public let isWritable: Bool
    public let posixPermissions: Int

    public init(
        path: String,
        size: UInt64,
        creationDate: Date?,
        modificationDate: Date?,
        isDirectory: Bool,
        isReadable: Bool,
        isWritable: Bool,
        posixPermissions: Int
    ) {
        self.path = path
        self.size = size
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.isDirectory = isDirectory
        self.isReadable = isReadable
        self.isWritable = isWritable
        self.posixPermissions = posixPermissions
    }
}
