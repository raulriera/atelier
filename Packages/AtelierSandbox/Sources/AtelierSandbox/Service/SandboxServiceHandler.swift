import Foundation
import AtelierSecurity

/// Implements the XPC wire protocol by dispatching to AtelierSecurity operators.
///
/// Runs in the XPC service process. Decodes each request, delegates to the
/// appropriate file operator, and encodes the response back.
public final class SandboxServiceHandler: NSObject, SandboxXPCProtocol, Sendable {
    private let coordinatedOperator: CoordinatedFileOperator
    private let safeOperator: SafeFileOperator
    private nonisolated(unsafe) let fileManager: FileManager

    public init(
        coordinatedOperator: CoordinatedFileOperator = CoordinatedFileOperator(),
        safeOperator: SafeFileOperator = SafeFileOperator(),
        fileManager: FileManager = .default
    ) {
        self.coordinatedOperator = coordinatedOperator
        self.safeOperator = safeOperator
        self.fileManager = fileManager
    }

    public func performOperation(
        _ requestData: Data,
        reply: @escaping @Sendable (Data?, Data?) -> Void
    ) {
        Task {
            do {
                let request = try XPCCoder.decode(SandboxRequest.self, from: requestData)
                let response = try await dispatch(request)
                let responseData = try XPCCoder.encode(response)
                reply(responseData, nil)
            } catch let error as SandboxError {
                let errorData = try? XPCCoder.encode(error)
                reply(nil, errorData)
            } catch {
                let sandboxError = SandboxError.operationFailed(
                    String(describing: error)
                )
                let errorData = try? XPCCoder.encode(sandboxError)
                reply(nil, errorData)
            }
        }
    }

    private func dispatch(_ request: SandboxRequest) async throws -> SandboxResponse {
        switch request {
        case .readFile(let path):
            let url = URL(fileURLWithPath: path)
            let data = try await coordinatedOperator.read(at: url)
            return .data(data)

        case .writeFile(let data, let path):
            let url = URL(fileURLWithPath: path)
            try await coordinatedOperator.write(data: data, to: url)
            return .empty

        case .moveFile(let source, let destination):
            let sourceURL = URL(fileURLWithPath: source)
            let destURL = URL(fileURLWithPath: destination)
            try await coordinatedOperator.move(from: sourceURL, to: destURL)
            return .empty

        case .copyFile(let source, let destination):
            let sourceURL = URL(fileURLWithPath: source)
            let destURL = URL(fileURLWithPath: destination)
            let result = await safeOperator.execute(
                operation: .copy(from: sourceURL, to: destURL)
            )
            try mapResult(result)
            return .empty

        case .trashFile(let path):
            let url = URL(fileURLWithPath: path)
            let result = await safeOperator.execute(operation: .trash(url))
            try mapResult(result)
            return .empty

        case .listDirectory(let path):
            let listing = try listDirectory(at: path)
            return .listing(listing)

        case .fileMetadata(let path):
            let metadata = try fileMetadata(at: path)
            return .metadata(metadata)
        }
    }

    private func mapResult(_ result: FileOperationResult) throws {
        switch result {
        case .success:
            return
        case .failure(_, let error):
            throw mapFileOperationError(error)
        }
    }

    private func mapFileOperationError(_ error: FileOperationError) -> SandboxError {
        switch error {
        case .fileNotFound(let url):
            return .fileNotFound(url.path)
        case .permissionDenied(let url):
            return .permissionDenied(url.path)
        case .destinationExists(let url):
            return .operationFailed("Destination exists: \(url.path)")
        case .trashFailed(let url, let underlying):
            return .operationFailed("Trash failed at \(url.path): \(underlying)")
        case .moveFailed(let from, let to, let underlying):
            return .operationFailed(
                "Move failed from \(from.path) to \(to.path): \(underlying)"
            )
        case .copyFailed(let from, let to, let underlying):
            return .operationFailed(
                "Copy failed from \(from.path) to \(to.path): \(underlying)"
            )
        case .renameFailed(let url, let newName, let underlying):
            return .operationFailed(
                "Rename failed at \(url.path) to \(newName): \(underlying)"
            )
        }
    }

    private func listDirectory(at path: String) throws -> DirectoryListing {
        let url = URL(fileURLWithPath: path)
        var isDir: ObjCBool = false

        guard fileManager.fileExists(atPath: path, isDirectory: &isDir),
              isDir.boolValue else {
            throw SandboxError.fileNotFound(path)
        }

        let contents: [URL]
        do {
            contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            throw SandboxError.operationFailed(
                "Failed to list directory \(path): \(error.localizedDescription)"
            )
        }

        let entries = contents.compactMap { itemURL -> DirectoryListing.Entry? in
            let values = try? itemURL.resourceValues(forKeys: [.isDirectoryKey])
            return DirectoryListing.Entry(
                name: itemURL.lastPathComponent,
                isDirectory: values?.isDirectory ?? false
            )
        }

        return DirectoryListing(path: path, entries: entries)
    }

    private func fileMetadata(at path: String) throws -> FileMetadata {
        guard fileManager.fileExists(atPath: path) else {
            throw SandboxError.fileNotFound(path)
        }

        let attributes: [FileAttributeKey: Any]
        do {
            attributes = try fileManager.attributesOfItem(atPath: path)
        } catch {
            throw SandboxError.operationFailed(
                "Failed to get metadata for \(path): \(error.localizedDescription)"
            )
        }

        let fileType = attributes[.type] as? FileAttributeType
        let isDirectory = fileType == .typeDirectory

        return FileMetadata(
            path: path,
            size: attributes[.size] as? UInt64 ?? 0,
            creationDate: attributes[.creationDate] as? Date,
            modificationDate: attributes[.modificationDate] as? Date,
            isDirectory: isDirectory,
            isReadable: fileManager.isReadableFile(atPath: path),
            isWritable: fileManager.isWritableFile(atPath: path),
            posixPermissions: (attributes[.posixPermissions] as? Int) ?? 0
        )
    }
}
