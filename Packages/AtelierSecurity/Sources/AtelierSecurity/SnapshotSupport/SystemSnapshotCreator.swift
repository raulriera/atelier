import Foundation

/// Real implementation using `diskutil apfs` commands via Process.
public struct SystemSnapshotCreator: SnapshotCreating {
    public init() {}

    public func create(name: String, volume: String) async throws -> SnapshotInfo {
        let output = try await run(
            arguments: ["apfs", "addSnapshot", volume, "-name", name]
        )

        guard output.contains("Created") || output.contains("snapshot") else {
            throw SnapshotError.creationFailed(underlying: output)
        }

        return SnapshotInfo(
            name: name,
            volume: volume,
            createdAt: Date()
        )
    }

    public func delete(name: String, volume: String) async throws {
        let output = try await run(
            arguments: ["apfs", "deleteSnapshot", volume, "-name", name]
        )

        guard !output.contains("error") && !output.contains("Error") else {
            throw SnapshotError.deletionFailed(underlying: output)
        }
    }

    public func list(volume: String) async throws -> [SnapshotInfo] {
        let output = try await run(
            arguments: ["apfs", "listSnapshots", volume]
        )

        guard !output.contains("not an APFS") else {
            throw SnapshotError.volumeNotAPFS(volume: volume)
        }

        // Parse snapshot names from diskutil output.
        // Lines containing "Name:" have the snapshot name.
        return output
            .components(separatedBy: .newlines)
            .filter { $0.contains("Name:") }
            .compactMap { line in
                let name = line
                    .components(separatedBy: "Name:")
                    .last?
                    .trimmingCharacters(in: .whitespaces)
                guard let name, !name.isEmpty else { return nil }
                return SnapshotInfo(
                    name: name,
                    volume: volume,
                    createdAt: Date()
                )
            }
    }

    private func run(arguments: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
            process.arguments = arguments

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""

                if process.terminationStatus != 0 && output.contains("Permission denied") {
                    continuation.resume(throwing: SnapshotError.insufficientPermissions)
                } else {
                    continuation.resume(returning: output)
                }
            } catch {
                continuation.resume(throwing: SnapshotError.creationFailed(
                    underlying: error.localizedDescription
                ))
            }
        }
    }
}
