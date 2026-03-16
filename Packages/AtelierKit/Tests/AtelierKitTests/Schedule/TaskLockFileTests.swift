import Foundation
import Testing
@testable import AtelierKit

@Suite("TaskLockFile")
struct TaskLockFileTests {

    // MARK: - Acquire / Release lifecycle

    @Test func acquireCreatesLockFileAndReleaseFreeIt() throws {
        let taskID = UUID()
        let url = TaskLockFile.lockURL(for: taskID)
        defer { try? FileManager.default.removeItem(at: url) }

        let fd = try #require(TaskLockFile.acquire(for: taskID))
        #expect(FileManager.default.fileExists(atPath: url.path))

        // While held, the lock file contains the PID
        let contents = try String(contentsOf: url, encoding: .utf8)
        #expect(contents.contains("\(ProcessInfo.processInfo.processIdentifier)"))

        TaskLockFile.release(fd: fd)
    }

    // MARK: - isLocked accuracy

    @Test func isLockedReturnsTrueWhileHeld() throws {
        let taskID = UUID()
        let url = TaskLockFile.lockURL(for: taskID)
        defer { try? FileManager.default.removeItem(at: url) }

        let fd = try #require(TaskLockFile.acquire(for: taskID))
        defer { TaskLockFile.release(fd: fd) }

        // Same-process BSD locks don't conflict (per-process granularity),
        // so we fork a child to do the probe — verifying the real cross-process
        // behavior that matters in production.
        let probeResult = try crossProcessIsLocked(taskID: taskID)
        #expect(probeResult == true)
    }

    @Test func isLockedReturnsFalseAfterRelease() throws {
        let taskID = UUID()
        let url = TaskLockFile.lockURL(for: taskID)
        defer { try? FileManager.default.removeItem(at: url) }

        let fd = try #require(TaskLockFile.acquire(for: taskID))
        TaskLockFile.release(fd: fd)

        // After release, a cross-process probe should succeed (not locked)
        let probeResult = try crossProcessIsLocked(taskID: taskID)
        #expect(probeResult == false)
    }

    // MARK: - Kernel auto-release on process exit

    @Test func lockReleasedWhenProcessExits() throws {
        let taskID = UUID()
        let url = TaskLockFile.lockURL(for: taskID)
        defer { try? FileManager.default.removeItem(at: url) }

        // Spawn a child that acquires the lock and exits without releasing
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [
            "-c",
            """
            import os, sys
            fd = os.open("\(url.path)", os.O_CREAT | os.O_RDWR | 0x20, 0o644)
            sys.exit(0)
            """
        ]
        try process.run()
        process.waitUntilExit()

        // Kernel should have released the lock on process exit
        let probeResult = try crossProcessIsLocked(taskID: taskID)
        #expect(probeResult == false)
    }

    // MARK: - Lock file path stability

    @Test func lockURLIsDeterministicForSameID() {
        let taskID = UUID()
        let first = TaskLockFile.lockURL(for: taskID)
        let second = TaskLockFile.lockURL(for: taskID)
        #expect(first == second)
        #expect(first.lastPathComponent == "\(taskID.uuidString).lock")
    }

    // MARK: - Helpers

    /// Forks a child process to attempt `open(O_EXLOCK | O_NONBLOCK)` and reports
    /// whether the lock is held. This avoids BSD's same-process lock re-entry.
    ///
    /// Uses Python (available on all macOS) to call POSIX `open()` with `O_EXLOCK`.
    /// Forks a child process to probe `O_EXLOCK | O_NONBLOCK`.
    /// Exit 0 = got lock (not locked), exit 1 = EAGAIN (locked), exit 2 = other error.
    private func crossProcessIsLocked(taskID: UUID) throws -> Bool {
        let url = TaskLockFile.lockURL(for: taskID)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [
            "-c",
            """
            import os, sys, errno
            try:
                fd = os.open("\(url.path)", os.O_RDWR | 0x20 | os.O_NONBLOCK)
                os.close(fd)
                sys.exit(0)
            except OSError as e:
                sys.exit(1 if e.errno == errno.EAGAIN else 2)
            """
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus == 1
    }
}
