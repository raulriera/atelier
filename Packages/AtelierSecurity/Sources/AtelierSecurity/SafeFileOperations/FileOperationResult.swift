import Foundation

/// The result of executing a single file operation.
public enum FileOperationResult: Sendable {
    case success(FileOperationRecord)
    case failure(FileOperation, FileOperationError)
}
