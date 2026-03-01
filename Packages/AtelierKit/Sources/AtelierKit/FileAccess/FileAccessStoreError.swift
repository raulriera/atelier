import Foundation

/// Errors surfaced to the user from ``FileAccessStore``.
public enum FileAccessStoreError: Error, Sendable {
    case grantFailed(url: URL, underlying: Error)

    /// A human-readable description suitable for display in the UI.
    public var localizedMessage: String {
        switch self {
        case .grantFailed(let url, _):
            return "Unable to grant access to \(url.lastPathComponent). Please try again."
        }
    }
}
