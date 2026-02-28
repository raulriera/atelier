/// Errors that can occur during snapshot operations.
public enum SnapshotError: Error, Sendable {
    case creationFailed(underlying: String)
    case deletionFailed(underlying: String)
    case listFailed(underlying: String)
    case volumeNotAPFS(volume: String)
    case insufficientPermissions
}
