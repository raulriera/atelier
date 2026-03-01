import Foundation

/// File-system-backed persistence using `Data(contentsOf:)` and atomic writes.
public struct SystemBookmarkPersistence: BookmarkPersistence {
    public init() {}

    public func read(from url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    public func write(_ data: Data, to url: URL) throws {
        try data.write(to: url, options: .atomic)
    }
}
