/// Recommendation based on Time Machine backup status.
public enum BackupRecommendation: String, Sendable {
    /// Backup is recent enough to proceed safely.
    case proceed

    /// Backup exists but may be stale — warn the user.
    case warn

    /// No backup is configured — inform the user.
    case noBackupConfigured
}
