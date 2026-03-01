/// Classifies the access level a sandbox request requires.
public enum FileAccessScope: String, Sendable {
    /// Read-only operations: readFile, listDirectory, fileMetadata.
    case read
    /// Mutating operations: writeFile, moveFile, copyFile, trashFile.
    case write
}

extension SandboxRequest {
    /// The access scope this request requires.
    public var requiredScope: FileAccessScope {
        switch self {
        case .readFile, .listDirectory, .fileMetadata:
            return .read
        case .writeFile, .moveFile, .copyFile, .trashFile:
            return .write
        }
    }

    /// All file paths this request touches.
    ///
    /// Single-path operations return one element; move/copy return both
    /// source and destination.
    public var affectedPaths: [String] {
        switch self {
        case .readFile(let path),
             .listDirectory(let path),
             .fileMetadata(let path),
             .trashFile(let path):
            return [path]
        case .writeFile(_, let path):
            return [path]
        case .moveFile(let source, let destination),
             .copyFile(let source, let destination):
            return [source, destination]
        }
    }
}
