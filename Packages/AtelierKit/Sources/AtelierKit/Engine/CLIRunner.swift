import Foundation

/// Abstraction over spawning a CLI process, enabling test injection.
protocol CLIRunner: Sendable {
    func run(arguments: [String], workingDirectory: URL) async throws -> String
}

/// Runs a real `Process` — the production implementation.
struct ProcessCLIRunner: CLIRunner {
    let executablePath: String

    func run(arguments: [String], workingDirectory: URL) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectory

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()

        // Read stdout BEFORE waitUntilExit to avoid deadlock if the
        // pipe buffer fills. readDataToEndOfFile blocks until the pipe
        // closes (process exits), so waitUntilExit returns immediately.
        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}
