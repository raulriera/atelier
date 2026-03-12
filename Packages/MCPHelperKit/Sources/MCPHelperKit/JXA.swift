import Foundation

/// Executes a JXA (JavaScript for Automation) script via `osascript`.
///
/// Returns the stdout output, stderr output, and exit code.
/// Used by capability helpers that control macOS apps via AppleScript/JXA.
public func executeJXA(_ script: String) -> (output: String, error: String, exitCode: Int32) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-l", "JavaScript", "-e", script]

    let stdoutPipe = Pipe()
    let stderrPipe = Pipe()
    process.standardOutput = stdoutPipe
    process.standardError = stderrPipe

    do {
        try process.run()
    } catch {
        return ("", "Failed to launch osascript: \(error.localizedDescription)", 1)
    }

    // Read pipe data before waitUntilExit to avoid deadlock when output exceeds
    // the pipe buffer (~64KB). The subprocess blocks on write if the buffer is full,
    // while we'd block on waitUntilExit — classic deadlock.
    let output = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    let errOutput = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

    process.waitUntilExit()
    return (output.trimmingCharacters(in: .whitespacesAndNewlines),
            errOutput.trimmingCharacters(in: .whitespacesAndNewlines),
            process.terminationStatus)
}

/// Escapes a Swift string for safe embedding inside a JXA string literal.
///
/// Handles backslashes, quotes, newlines, carriage returns, and tabs.
public func jxaEscape(_ s: String) -> String {
    s.replacingOccurrences(of: "\\", with: "\\\\")
     .replacingOccurrences(of: "\"", with: "\\\"")
     .replacingOccurrences(of: "\n", with: "\\n")
     .replacingOccurrences(of: "\r", with: "\\r")
     .replacingOccurrences(of: "\t", with: "\\t")
}
