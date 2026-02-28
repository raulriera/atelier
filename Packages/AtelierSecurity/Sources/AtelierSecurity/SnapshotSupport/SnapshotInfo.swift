import Foundation

/// Metadata for an APFS snapshot.
public struct SnapshotInfo: Sendable {
    /// The snapshot name.
    public let name: String

    /// The volume the snapshot belongs to.
    public let volume: String

    /// When the snapshot was created.
    public let createdAt: Date

    public init(name: String, volume: String, createdAt: Date) {
        self.name = name
        self.volume = volume
        self.createdAt = createdAt
    }
}
