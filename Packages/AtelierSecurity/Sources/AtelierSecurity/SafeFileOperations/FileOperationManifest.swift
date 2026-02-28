import Foundation

/// A batch plan of file operations with metadata.
public struct FileOperationManifest: Sendable {
    public let operations: [FileOperation]
    public let description: String
    public let createdAt: Date

    public init(
        operations: [FileOperation],
        description: String,
        createdAt: Date = Date()
    ) {
        self.operations = operations
        self.description = description
        self.createdAt = createdAt
    }

    public var trashCount: Int {
        operations.filter { if case .trash = $0 { return true }; return false }.count
    }

    public var moveCount: Int {
        operations.filter { if case .move = $0 { return true }; return false }.count
    }

    public var copyCount: Int {
        operations.filter { if case .copy = $0 { return true }; return false }.count
    }

    public var renameCount: Int {
        operations.filter { if case .rename = $0 { return true }; return false }.count
    }

    public var totalCount: Int { operations.count }
}
