import Foundation

/// Orchestrates snapshot creation and backup checking with audit logging.
public final class SnapshotManager: Sendable {
    private let snapshotCreator: SnapshotCreating
    private let timeMachineChecker: TimeMachineChecking
    private let auditLogger: AuditLogger

    /// Maximum age in hours for a backup to be considered fresh.
    private let backupFreshnessHours: Double

    public init(
        snapshotCreator: SnapshotCreating = SystemSnapshotCreator(),
        timeMachineChecker: TimeMachineChecking = SystemTimeMachineChecker(),
        auditLogger: AuditLogger = NullAuditLogger(),
        backupFreshnessHours: Double = 24
    ) {
        self.snapshotCreator = snapshotCreator
        self.timeMachineChecker = timeMachineChecker
        self.auditLogger = auditLogger
        self.backupFreshnessHours = backupFreshnessHours
    }

    /// Creates a snapshot as a safety net before a batch operation.
    ///
    /// - Parameters:
    ///   - name: The snapshot name (e.g., "atelier-pre-operation-<timestamp>").
    ///   - volume: The volume to snapshot.
    /// - Returns: The created snapshot info.
    @discardableResult
    public func prepareForBatchOperation(
        name: String,
        volume: String
    ) async throws -> SnapshotInfo {
        let snapshot = try await snapshotCreator.create(name: name, volume: volume)

        await auditLogger.log(AuditEvent(
            category: .snapshot,
            action: "create",
            subject: name,
            detail: "volume: \(volume)"
        ))

        return snapshot
    }

    /// Checks Time Machine backup status and returns a recommendation.
    public func checkBackupStatus() async -> BackupStatus {
        let configured = await timeMachineChecker.isConfigured()

        guard configured else {
            return BackupStatus(
                isConfigured: false,
                lastBackupDate: nil,
                recommendation: .noBackupConfigured
            )
        }

        let lastDate = await timeMachineChecker.lastBackupDate()

        let recommendation: BackupRecommendation
        if let lastDate {
            let hoursSinceBackup = Date().timeIntervalSince(lastDate) / 3600
            recommendation = hoursSinceBackup <= backupFreshnessHours ? .proceed : .warn
        } else {
            recommendation = .warn
        }

        await auditLogger.log(AuditEvent(
            category: .snapshot,
            action: "backup-check",
            subject: "time-machine",
            detail: "recommendation: \(recommendation.rawValue)"
        ))

        return BackupStatus(
            isConfigured: configured,
            lastBackupDate: lastDate,
            recommendation: recommendation
        )
    }

    /// Lists existing snapshots on a volume.
    public func listSnapshots(volume: String) async throws -> [SnapshotInfo] {
        try await snapshotCreator.list(volume: volume)
    }

    /// Deletes a snapshot by name.
    public func deleteSnapshot(name: String, volume: String) async throws {
        try await snapshotCreator.delete(name: name, volume: volume)

        await auditLogger.log(AuditEvent(
            category: .snapshot,
            action: "delete",
            subject: name,
            detail: "volume: \(volume)"
        ))
    }
}
