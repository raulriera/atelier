import Foundation

/// Abstracts `URL.bookmarkData()` creation for testability.
public protocol BookmarkCreator: Sendable {
    func createBookmarkData(for url: URL, readOnly: Bool) throws -> Data
}
