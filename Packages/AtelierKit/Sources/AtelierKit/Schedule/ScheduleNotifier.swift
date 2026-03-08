import Foundation
import UserNotifications
import os

/// Posts a local notification when a scheduled task completes.
///
/// For v1, the helper binary writes results to the log file.
/// The app reads logs on launch and surfaces results.
/// v2: helper binary posts `UNUserNotificationCenter` notifications directly.
public struct ScheduleNotifier: Sendable {
    private static let logger = Logger(
        subsystem: "com.atelier.kit",
        category: "Schedule"
    )

    /// Posts a completion notification for a scheduled task.
    ///
    /// On failure the notification body includes the log path so the user
    /// can ask Atelier's agent to read it and help diagnose the problem.
    ///
    /// - Parameters:
    ///   - taskName: The user-facing name of the task that completed.
    ///   - succeeded: Whether the task run succeeded.
    ///   - logPath: Absolute path to the task's log file, shown on failure.
    public static func postCompletion(taskName: String, succeeded: Bool, logPath: String? = nil) async {
        let content = UNMutableNotificationContent()
        content.title = succeeded ? "Task completed" : "Task failed"
        if succeeded {
            content.body = taskName
        } else {
            content.body = "\(taskName) — ask Atelier to read the log and help fix it"
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            logger.debug("Posted completion notification for '\(taskName)'")
        } catch {
            logger.warning("Failed to post notification: \(error.localizedDescription)")
        }
    }

    /// Requests notification permission from the user.
    ///
    /// - Returns: Whether permission was granted.
    public static func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            logger.info("Notification permission \(granted ? "granted" : "denied")")
            return granted
        } catch {
            logger.warning("Notification permission request failed: \(error.localizedDescription)")
            return false
        }
    }
}
