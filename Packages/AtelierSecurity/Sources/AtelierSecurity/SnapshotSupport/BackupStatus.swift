import Foundation

/// Result of a Time Machine backup status check.
public struct BackupStatus: Sendable {
    /// Whether Time Machine is configured on this system.
    public let isConfigured: Bool

    /// The date of the most recent backup, if available.
    public let lastBackupDate: Date?

    /// The recommended action based on backup freshness.
    public let recommendation: BackupRecommendation

    public init(
        isConfigured: Bool,
        lastBackupDate: Date?,
        recommendation: BackupRecommendation
    ) {
        self.isConfigured = isConfigured
        self.lastBackupDate = lastBackupDate
        self.recommendation = recommendation
    }
}
