import Foundation

/// Abstracts APFS snapshot operations for testability.
public protocol SnapshotCreating: Sendable {
    /// Creates a snapshot on the volume containing the given path.
    func create(name: String, volume: String) async throws -> SnapshotInfo

    /// Deletes a snapshot by name on the given volume.
    func delete(name: String, volume: String) async throws

    /// Lists all snapshots on the given volume.
    func list(volume: String) async throws -> [SnapshotInfo]
}
