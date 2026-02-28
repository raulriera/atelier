import Foundation
import Testing
@testable import AtelierSecurity

// MARK: - Mocks

private final class MockSnapshotCreator: SnapshotCreating, @unchecked Sendable {
    var snapshots: [SnapshotInfo] = []
    var shouldFailOnCreate = false
    var shouldFailOnDelete = false
    var shouldFailOnList = false

    func create(name: String, volume: String) async throws -> SnapshotInfo {
        if shouldFailOnCreate {
            throw SnapshotError.creationFailed(underlying: "mock create failure")
        }
        let info = SnapshotInfo(name: name, volume: volume, createdAt: Date())
        snapshots.append(info)
        return info
    }

    func delete(name: String, volume: String) async throws {
        if shouldFailOnDelete {
            throw SnapshotError.deletionFailed(underlying: "mock delete failure")
        }
        snapshots.removeAll { $0.name == name }
    }

    func list(volume: String) async throws -> [SnapshotInfo] {
        if shouldFailOnList {
            throw SnapshotError.listFailed(underlying: "mock list failure")
        }
        return snapshots.filter { $0.volume == volume }
    }
}

private struct MockTimeMachineChecker: TimeMachineChecking {
    var configured: Bool = false
    var lastDate: Date?

    func isConfigured() async -> Bool {
        configured
    }

    func lastBackupDate() async -> Date? {
        lastDate
    }
}

@Suite("SnapshotManager")
struct SnapshotManagerTests {

    @Test func prepareForBatchOperationCreatesSnapshot() async throws {
        let creator = MockSnapshotCreator()
        let logger = InMemoryAuditLogger()
        let manager = SnapshotManager(
            snapshotCreator: creator,
            auditLogger: logger
        )

        let snapshot = try await manager.prepareForBatchOperation(
            name: "pre-op-1",
            volume: "/dev/disk1"
        )

        #expect(snapshot.name == "pre-op-1")
        #expect(snapshot.volume == "/dev/disk1")
        #expect(creator.snapshots.count == 1)

        let events = await logger.events(category: .snapshot, since: nil, limit: nil)
        #expect(events.count == 1)
        #expect(events[0].action == "create")
    }

    @Test func prepareFailsPropagatesError() async {
        let creator = MockSnapshotCreator()
        creator.shouldFailOnCreate = true
        let manager = SnapshotManager(snapshotCreator: creator)

        do {
            _ = try await manager.prepareForBatchOperation(name: "fail", volume: "/dev/disk1")
            Issue.record("Expected creationFailed error")
        } catch let error as SnapshotError {
            if case .creationFailed = error {} else {
                Issue.record("Expected creationFailed, got \(error)")
            }
        } catch {
            Issue.record("Expected SnapshotError, got \(error)")
        }
    }

    @Test func checkBackupStatusWhenNotConfigured() async {
        let checker = MockTimeMachineChecker(configured: false)
        let manager = SnapshotManager(timeMachineChecker: checker)

        let status = await manager.checkBackupStatus()
        #expect(!status.isConfigured)
        #expect(status.lastBackupDate == nil)
        #expect(status.recommendation == .noBackupConfigured)
    }

    @Test func checkBackupStatusWithRecentBackup() async {
        let recentDate = Date().addingTimeInterval(-3600) // 1 hour ago
        let checker = MockTimeMachineChecker(configured: true, lastDate: recentDate)
        let logger = InMemoryAuditLogger()
        let manager = SnapshotManager(
            timeMachineChecker: checker,
            auditLogger: logger,
            backupFreshnessHours: 24
        )

        let status = await manager.checkBackupStatus()
        #expect(status.isConfigured)
        #expect(status.lastBackupDate == recentDate)
        #expect(status.recommendation == .proceed)

        let events = await logger.events(category: .snapshot, since: nil, limit: nil)
        #expect(events.count == 1)
        #expect(events[0].action == "backup-check")
    }

    @Test func checkBackupStatusWithStaleBackup() async {
        let staleDate = Date().addingTimeInterval(-48 * 3600) // 48 hours ago
        let checker = MockTimeMachineChecker(configured: true, lastDate: staleDate)
        let manager = SnapshotManager(
            timeMachineChecker: checker,
            backupFreshnessHours: 24
        )

        let status = await manager.checkBackupStatus()
        #expect(status.isConfigured)
        #expect(status.recommendation == .warn)
    }

    @Test func checkBackupStatusConfiguredButNoDate() async {
        let checker = MockTimeMachineChecker(configured: true, lastDate: nil)
        let manager = SnapshotManager(timeMachineChecker: checker)

        let status = await manager.checkBackupStatus()
        #expect(status.isConfigured)
        #expect(status.recommendation == .warn)
    }

    @Test func deleteSnapshotLogsEvent() async throws {
        let creator = MockSnapshotCreator()
        let logger = InMemoryAuditLogger()
        let manager = SnapshotManager(
            snapshotCreator: creator,
            auditLogger: logger
        )

        // Create then delete.
        _ = try await manager.prepareForBatchOperation(name: "to-delete", volume: "/dev/disk1")
        try await manager.deleteSnapshot(name: "to-delete", volume: "/dev/disk1")

        #expect(creator.snapshots.isEmpty)

        let events = await logger.events(category: .snapshot, since: nil, limit: nil)
        #expect(events.count == 2) // create + delete
        #expect(events[1].action == "delete")
    }

    @Test func listSnapshotsFiltersVolume() async throws {
        let creator = MockSnapshotCreator()
        let manager = SnapshotManager(snapshotCreator: creator)

        _ = try await manager.prepareForBatchOperation(name: "snap-a", volume: "/dev/disk1")
        _ = try await manager.prepareForBatchOperation(name: "snap-b", volume: "/dev/disk2")

        let disk1Snapshots = try await manager.listSnapshots(volume: "/dev/disk1")
        #expect(disk1Snapshots.count == 1)
        #expect(disk1Snapshots[0].name == "snap-a")
    }
}
