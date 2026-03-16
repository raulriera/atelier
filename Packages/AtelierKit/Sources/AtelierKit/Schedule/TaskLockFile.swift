import Foundation
import os

/// BSD advisory file lock management for scheduled task execution.
///
/// Uses `O_EXLOCK` to provide kernel-managed exclusive locks that are
/// automatically released on process exit, crash, or SIGKILL — no stale
/// state possible. Lock files live at `~/Library/Logs/Atelier/tasks/{id}.lock`.
public struct TaskLockFile: Sendable {
    private static let logger = Logger(subsystem: "com.atelier.kit", category: "TaskLock")

    /// Directory containing task lock files.
    private static let lockDirectory: URL =
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/Atelier/tasks")

    /// Returns the lock file URL for a given task ID.
    public static func lockURL(for taskID: UUID) -> URL {
        lockDirectory.appendingPathComponent("\(taskID.uuidString).lock")
    }

    /// Ensures the lock directory exists. Called once per process lifetime.
    private static let ensureDirectory: Void = {
        try? FileManager.default.createDirectory(at: lockDirectory, withIntermediateDirectories: true)
    }()

    /// Acquires an exclusive lock for the given task.
    ///
    /// Opens the lock file with `O_EXLOCK`, writes the current PID for
    /// debugging, and returns the file descriptor. The caller must keep
    /// the fd open for the duration of the task and call ``release(fd:)``
    /// when done.
    ///
    /// - Returns: The file descriptor, or `nil` if the lock could not be acquired.
    public static func acquire(for taskID: UUID) -> Int32? {
        _ = ensureDirectory

        let url = lockURL(for: taskID)
        let fd = Darwin.open(url.path, O_CREAT | O_RDWR | O_EXLOCK, 0o644)
        guard fd >= 0 else {
            logger.warning("Failed to acquire lock for task \(taskID): errno \(errno)")
            return nil
        }

        // Write PID for debugging visibility
        let pid = "\(ProcessInfo.processInfo.processIdentifier)\n"
        pid.withCString { buf in
            _ = ftruncate(fd, 0)
            _ = Darwin.write(fd, buf, strlen(buf))
        }

        logger.info("Acquired lock for task \(taskID) (fd \(fd))")
        return fd
    }

    /// Releases a previously acquired lock by closing the file descriptor.
    ///
    /// The kernel automatically releases the advisory lock when the fd is closed.
    public static func release(fd: Int32) {
        Darwin.close(fd)
        logger.info("Released lock (fd \(fd))")
    }

    /// Checks whether a task is currently locked (running).
    ///
    /// Attempts a non-blocking exclusive lock on the file. If it fails with
    /// `EAGAIN`, another process holds the lock. If the file doesn't exist
    /// (task never ran) or any other error occurs, the task is not running.
    ///
    /// - Returns: `true` if the task's lock file is held by another process.
    public static func isLocked(taskID: UUID) -> Bool {
        let url = lockURL(for: taskID)
        let fd = Darwin.open(url.path, O_RDWR | O_EXLOCK | O_NONBLOCK)

        if fd < 0 {
            // EAGAIN/EWOULDBLOCK = another process holds the lock.
            // ENOENT = lock file doesn't exist (task never ran). Other errors = not running.
            return errno == EAGAIN || errno == EWOULDBLOCK
        }

        // We got the lock — task is not running. Release immediately.
        Darwin.close(fd)
        return false
    }
}
