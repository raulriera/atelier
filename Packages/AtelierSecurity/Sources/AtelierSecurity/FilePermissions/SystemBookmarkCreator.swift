import Foundation

/// Creates security-scoped bookmarks using the system APIs.
public struct SystemBookmarkCreator: BookmarkCreator {
    public init() {}

    public func createBookmarkData(for url: URL, readOnly: Bool) throws -> Data {
        var options: URL.BookmarkCreationOptions = [.withSecurityScope]
        if readOnly {
            options.insert(.securityScopeAllowOnlyReadAccess)
        }
        return try url.bookmarkData(
            options: options,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }
}
