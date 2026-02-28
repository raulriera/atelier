import Foundation

/// Orchestrates safe file operations with audit logging.
///
/// All destructive operations go through Trash — no direct deletion.
public final class SafeFileOperator: Sendable {
    private let fileOperator: FileOperating
    private let auditLogger: AuditLogger

    public init(
        fileOperator: FileOperating = SystemFileOperator(),
        auditLogger: AuditLogger = NullAuditLogger()
    ) {
        self.fileOperator = fileOperator
        self.auditLogger = auditLogger
    }

    /// Creates an operation manifest (a plan) from a list of operations.
    public func plan(
        operations: [FileOperation],
        description: String
    ) -> FileOperationManifest {
        FileOperationManifest(
            operations: operations,
            description: description
        )
    }

    /// Executes all operations in a manifest, returning results for each.
    public func execute(manifest: FileOperationManifest) async -> [FileOperationResult] {
        var results: [FileOperationResult] = []

        for operation in manifest.operations {
            let result = await execute(operation: operation)
            results.append(result)
        }

        return results
    }

    /// Executes a single file operation.
    public func execute(operation: FileOperation) async -> FileOperationResult {
        switch operation {
        case .trash(let url):
            return await executeTrash(url: url)
        case .move(let from, let to):
            return await executeMove(from: from, to: to)
        case .copy(let from, let to):
            return await executeCopy(from: from, to: to)
        case .rename(let url, let newName):
            return await executeRename(url: url, newName: newName)
        }
    }

    private func executeTrash(url: URL) async -> FileOperationResult {
        guard fileOperator.fileExists(at: url) else {
            return .failure(.trash(url), .fileNotFound(url))
        }

        do {
            let trashURL = try fileOperator.trashItem(at: url)
            let record = FileOperationRecord(
                operation: .trash(url),
                resultURL: trashURL
            )

            await auditLogger.log(AuditEvent(
                category: .fileOperation,
                action: "trash",
                subject: url.path,
                detail: "Moved to: \(trashURL.path)"
            ))

            return .success(record)
        } catch {
            return .failure(
                .trash(url),
                .trashFailed(url, underlying: error.localizedDescription)
            )
        }
    }

    private func executeMove(from: URL, to: URL) async -> FileOperationResult {
        guard fileOperator.fileExists(at: from) else {
            return .failure(.move(from: from, to: to), .fileNotFound(from))
        }
        if fileOperator.fileExists(at: to) {
            return .failure(.move(from: from, to: to), .destinationExists(to))
        }

        do {
            try fileOperator.moveItem(from: from, to: to)
            let record = FileOperationRecord(
                operation: .move(from: from, to: to),
                resultURL: to
            )

            await auditLogger.log(AuditEvent(
                category: .fileOperation,
                action: "move",
                subject: from.path,
                detail: "Destination: \(to.path)"
            ))

            return .success(record)
        } catch {
            return .failure(
                .move(from: from, to: to),
                .moveFailed(from: from, to: to, underlying: error.localizedDescription)
            )
        }
    }

    private func executeCopy(from: URL, to: URL) async -> FileOperationResult {
        guard fileOperator.fileExists(at: from) else {
            return .failure(.copy(from: from, to: to), .fileNotFound(from))
        }
        if fileOperator.fileExists(at: to) {
            return .failure(.copy(from: from, to: to), .destinationExists(to))
        }

        do {
            try fileOperator.copyItem(from: from, to: to)
            let record = FileOperationRecord(
                operation: .copy(from: from, to: to),
                resultURL: to
            )

            await auditLogger.log(AuditEvent(
                category: .fileOperation,
                action: "copy",
                subject: from.path,
                detail: "Destination: \(to.path)"
            ))

            return .success(record)
        } catch {
            return .failure(
                .copy(from: from, to: to),
                .copyFailed(from: from, to: to, underlying: error.localizedDescription)
            )
        }
    }

    private func executeRename(url: URL, newName: String) async -> FileOperationResult {
        guard fileOperator.fileExists(at: url) else {
            return .failure(.rename(from: url, newName: newName), .fileNotFound(url))
        }

        let destination = url.deletingLastPathComponent().appendingPathComponent(newName)
        if fileOperator.fileExists(at: destination) {
            return .failure(
                .rename(from: url, newName: newName),
                .destinationExists(destination)
            )
        }

        do {
            try fileOperator.moveItem(from: url, to: destination)
            let record = FileOperationRecord(
                operation: .rename(from: url, newName: newName),
                resultURL: destination
            )

            await auditLogger.log(AuditEvent(
                category: .fileOperation,
                action: "rename",
                subject: url.path,
                detail: "New name: \(newName)"
            ))

            return .success(record)
        } catch {
            return .failure(
                .rename(from: url, newName: newName),
                .renameFailed(url, newName: newName, underlying: error.localizedDescription)
            )
        }
    }
}
