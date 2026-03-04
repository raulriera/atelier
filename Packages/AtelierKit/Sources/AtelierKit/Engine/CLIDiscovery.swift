import Foundation

/// Shared CLI path discovery used by both CLIEngine and DistillationEngine.
enum CLIDiscovery {

    /// The real user home directory, bypassing sandbox container redirection.
    static var realHomeDirectory: String {
        if let pw = getpwuid(getuid()) {
            return String(cString: pw.pointee.pw_dir)
        }
        return NSHomeDirectory()
    }

    /// Locates the `claude` CLI binary on disk.
    ///
    /// Checks well-known install locations first, then falls back to `which`.
    static func findCLI() -> String {
        let home = realHomeDirectory

        let candidates = [
            "\(home)/.local/bin/claude",
            "\(home)/.claude/bin/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
        ]

        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Fall back to PATH lookup
        let whichProcess = Process()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = ["claude"]
        let pipe = Pipe()
        whichProcess.standardOutput = pipe
        try? whichProcess.run()
        whichProcess.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        return output.isEmpty ? "claude" : output
    }

    /// Whether the CLI binary can be found and is executable.
    static var isAvailable: Bool {
        let path = findCLI()
        return FileManager.default.isExecutableFile(atPath: path)
    }
}
