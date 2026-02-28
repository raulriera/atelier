import Foundation

/// Abstracts Time Machine status checking for testability.
public protocol TimeMachineChecking: Sendable {
    /// Whether Time Machine is configured on this system.
    func isConfigured() async -> Bool

    /// The date of the most recent backup, if available.
    func lastBackupDate() async -> Date?
}
