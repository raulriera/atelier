import Foundation

/// A record of a completed file operation.
public struct FileOperationRecord: Sendable {
    public let operation: FileOperation
    public let resultURL: URL?
    public let completedAt: Date

    public init(
        operation: FileOperation,
        resultURL: URL? = nil,
        completedAt: Date = Date()
    ) {
        self.operation = operation
        self.resultURL = resultURL
        self.completedAt = completedAt
    }
}
