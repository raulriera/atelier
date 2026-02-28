import Foundation

/// Errors that can occur during file permission operations.
public enum FilePermissionError: Error, Sendable {
    case bookmarkCreationFailed(URL, underlying: Error)
    case bookmarkStale(URL)
    case accessDenied(URL)
    case noBookmarkFound(URL)
    case bookmarkResolutionFailed(URL, underlying: Error)
}
