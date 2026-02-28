import Foundation

/// Real implementation using `tmutil` to check Time Machine status.
public struct SystemTimeMachineChecker: TimeMachineChecking {
    public init() {}

    public func isConfigured() async -> Bool {
        let date = await lastBackupDate()
        return date != nil
    }

    public func lastBackupDate() async -> Date? {
        do {
            let output = try await run(arguments: ["latestbackup"])
            let path = output.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !path.isEmpty else { return nil }

            // Extract the date from the backup path.
            // Typical format: /Volumes/Backup/Backups.backupdb/Machine/2024-01-15-123456
            let components = path.components(separatedBy: "/")
            guard let last = components.last else { return nil }

            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd-HHmmss"
            return formatter.date(from: last)
        } catch {
            return nil
        }
    }

    private func run(arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
            process.arguments = arguments

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                continuation.resume(returning: output)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
