import Foundation

/// Abstracts NSFileCoordinator operations for testability.
public protocol FileCoordinating: Sendable {
    /// Coordinates reading a file and returns its data.
    func coordinateReading(at url: URL) async throws -> Data

    /// Coordinates writing data to a file.
    func coordinateWriting(data: Data, to url: URL) async throws

    /// Coordinates moving a file from one location to another.
    func coordinateMoving(from source: URL, to destination: URL) async throws
}
