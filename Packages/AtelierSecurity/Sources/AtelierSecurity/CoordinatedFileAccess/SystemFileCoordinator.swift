import Foundation

/// Real implementation using NSFileCoordinator with async/await bridging.
public struct SystemFileCoordinator: FileCoordinating {
    public init() {}

    public func coordinateReading(at url: URL) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let coordinator = NSFileCoordinator()
            var coordinatorError: NSError?

            coordinator.coordinate(
                readingItemAt: url,
                options: [],
                error: &coordinatorError
            ) { readURL in
                do {
                    let data = try Data(contentsOf: readURL)
                    continuation.resume(returning: data)
                } catch {
                    continuation.resume(throwing: CoordinatedFileError.readFailed(
                        url,
                        underlying: error.localizedDescription
                    ))
                }
            }

            if let coordinatorError {
                continuation.resume(throwing: CoordinatedFileError.coordinationFailed(
                    underlying: coordinatorError.localizedDescription
                ))
            }
        }
    }

    public func coordinateWriting(data: Data, to url: URL) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let coordinator = NSFileCoordinator()
            var coordinatorError: NSError?

            coordinator.coordinate(
                writingItemAt: url,
                options: [],
                error: &coordinatorError
            ) { writeURL in
                do {
                    try data.write(to: writeURL)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: CoordinatedFileError.writeFailed(
                        url,
                        underlying: error.localizedDescription
                    ))
                }
            }

            if let coordinatorError {
                continuation.resume(throwing: CoordinatedFileError.coordinationFailed(
                    underlying: coordinatorError.localizedDescription
                ))
            }
        }
    }

    public func coordinateMoving(from source: URL, to destination: URL) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let coordinator = NSFileCoordinator()
            var coordinatorError: NSError?

            coordinator.coordinate(
                writingItemAt: source,
                options: .forMoving,
                writingItemAt: destination,
                options: .forReplacing,
                error: &coordinatorError
            ) { sourceURL, destURL in
                do {
                    try FileManager.default.moveItem(at: sourceURL, to: destURL)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: CoordinatedFileError.moveFailed(
                        from: source,
                        to: destination,
                        underlying: error.localizedDescription
                    ))
                }
            }

            if let coordinatorError {
                continuation.resume(throwing: CoordinatedFileError.coordinationFailed(
                    underlying: coordinatorError.localizedDescription
                ))
            }
        }
    }
}
