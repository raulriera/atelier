import Foundation

/// Orchestrates coordinated file access with audit logging.
public final class CoordinatedFileOperator: Sendable {
    private let coordinator: FileCoordinating
    private let auditLogger: AuditLogger

    public init(
        coordinator: FileCoordinating = SystemFileCoordinator(),
        auditLogger: AuditLogger = NullAuditLogger()
    ) {
        self.coordinator = coordinator
        self.auditLogger = auditLogger
    }

    /// Reads a file using coordinated access.
    public func read(at url: URL) async throws -> Data {
        let data = try await coordinator.coordinateReading(at: url)

        await auditLogger.log(AuditEvent(
            category: .fileOperation,
            action: "coordinated-read",
            subject: url.path,
            detail: "\(data.count) bytes"
        ))

        return data
    }

    /// Writes data to a file using coordinated access.
    public func write(data: Data, to url: URL) async throws {
        try await coordinator.coordinateWriting(data: data, to: url)

        await auditLogger.log(AuditEvent(
            category: .fileOperation,
            action: "coordinated-write",
            subject: url.path,
            detail: "\(data.count) bytes"
        ))
    }

    /// Moves a file using coordinated access.
    public func move(from source: URL, to destination: URL) async throws {
        try await coordinator.coordinateMoving(from: source, to: destination)

        await auditLogger.log(AuditEvent(
            category: .fileOperation,
            action: "coordinated-move",
            subject: source.path,
            detail: "Destination: \(destination.path)"
        ))
    }
}
