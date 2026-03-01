import Foundation
import os

public final class CLIEngine: ConversationEngine, Sendable {
    private let cliPath: String

    public init(cliPath: String? = nil) {
        self.cliPath = cliPath ?? Self.findCLI()
    }

    public func send(
        message: String,
        model: ModelConfiguration,
        sessionId: String? = nil,
        workingDirectory: URL? = nil
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        let path = cliPath
        let alias = model.cliAlias
        let cwd = workingDirectory ?? FileManager.default.temporaryDirectory
        let processLock = OSAllocatedUnfairLock<Process?>(initialState: nil)

        return AsyncThrowingStream { continuation in
            let task = Task.detached {
                do {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: path)
                    process.arguments = Self.buildArguments(
                        message: message, modelAlias: alias, sessionId: sessionId
                    )

                    // Use the project's root directory so the CLI can see project files,
                    // or fall back to a temp directory for scratchpad sessions.
                    process.currentDirectoryURL = cwd

                    let stdout = Pipe()
                    let stderr = Pipe()
                    process.standardOutput = stdout
                    process.standardError = stderr

                    try process.run()
                    processLock.withLock { $0 = process }

                    let handle = stdout.fileHandleForReading

                    for try await line in handle.bytes.lines {
                        if Task.isCancelled { break }

                        guard let data = line.data(using: .utf8) else { continue }

                        let decoder = JSONDecoder()

                        // Peek at the type field
                        guard let envelope = try? decoder.decode(CLIMessage.self, from: data) else {
                            continue
                        }

                        switch envelope.type {
                        case "system":
                            if envelope.subtype == "init",
                               let initEvent = try? decoder.decode(CLISystemInit.self, from: data) {
                                continuation.yield(.sessionStarted(initEvent.sessionId))
                            }

                        case "stream_event":
                            if let streamEvent = try? decoder.decode(CLIStreamEvent.self, from: data) {
                                Self.handleStreamEvent(streamEvent.event, continuation: continuation)
                            }

                        case "result":
                            if let result = try? decoder.decode(CLIResult.self, from: data) {
                                let usage = TokenUsage(
                                    inputTokens: result.usage?.inputTokens ?? 0,
                                    outputTokens: result.usage?.outputTokens ?? 0
                                )
                                if result.isError == true {
                                    continuation.yield(.error(.cliError(result.result ?? "Unknown error")))
                                } else {
                                    continuation.yield(.messageComplete(usage))
                                }
                            }

                        default:
                            // assistant, user — ignore for streaming purposes
                            break
                        }
                    }

                    process.waitUntilExit()

                    if process.terminationStatus != 0 && !Task.isCancelled {
                        let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
                        let stderrText = String(data: stderrData, encoding: .utf8) ?? ""
                        continuation.finish(throwing: EngineError.processFailure(
                            exitCode: Int(process.terminationStatus),
                            stderr: stderrText
                        ))
                    } else {
                        continuation.finish()
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
                processLock.withLock { $0?.terminate() }
            }
        }
    }

    private static func handleStreamEvent(
        _ event: RawStreamEvent,
        continuation: AsyncThrowingStream<StreamEvent, Error>.Continuation
    ) {
        switch event.type {
        case "content_block_start":
            if event.contentBlock?.type == "thinking" {
                continuation.yield(.thinkingStarted)
            }

        case "content_block_delta":
            guard let delta = event.delta else { return }
            switch delta.type {
            case "text_delta":
                if let text = delta.text {
                    continuation.yield(.textDelta(text))
                }
            case "thinking_delta":
                if let thinking = delta.thinking {
                    continuation.yield(.thinkingDelta(thinking))
                }
            default:
                break
            }

        default:
            break
        }
    }

    // MARK: - Argument Building

    static func buildArguments(
        message: String,
        modelAlias: String,
        sessionId: String?
    ) -> [String] {
        var args = [
            "-p", message,
            "--output-format", "stream-json",
            "--verbose",
            "--include-partial-messages",
            "--model", modelAlias,
            "--max-turns", "1",
        ]

        if let sessionId {
            args += ["--resume", sessionId]
        }

        return args
    }

    // MARK: - CLI Discovery

    /// Returns the real user home directory, bypassing sandbox container redirection.
    private static var realHomeDirectory: String {
        if let pw = getpwuid(getuid()) {
            return String(cString: pw.pointee.pw_dir)
        }
        return NSHomeDirectory()
    }

    private static func findCLI() -> String {
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

    public static var isAvailable: Bool {
        let path = findCLI()
        return FileManager.default.isExecutableFile(atPath: path)
    }
}
