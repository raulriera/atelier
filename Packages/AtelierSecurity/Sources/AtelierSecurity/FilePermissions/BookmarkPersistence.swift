import Foundation

/// Abstraction over file I/O for bookmark data, enabling test doubles.
public protocol BookmarkPersistence: Sendable {
    func read(from url: URL) throws -> Data
    func write(_ data: Data, to url: URL) throws
}
