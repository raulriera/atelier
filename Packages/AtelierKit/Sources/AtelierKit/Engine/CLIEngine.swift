import Foundation
import os

public final class CLIEngine: ConversationEngine, Sendable {
    private static let logger = Logger(subsystem: "com.atelier.kit", category: "CLIEngine")
    private let cliPath: String

    public init(cliPath: String? = nil) {
        self.cliPath = cliPath ?? CLIDiscovery.findCLI()
    }

    public func send(
        message: String,
        model: ModelConfiguration,
        sessionId: String? = nil,
        workingDirectory: URL? = nil,
        appendSystemPrompt: String? = nil,
        approvalSocketPath: String? = nil,
        enabledCapabilities: [MCPServerConfig] = []
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        let path = cliPath
        let alias = model.cliAlias
        let cwd = workingDirectory ?? FileManager.default.temporaryDirectory
        let processLock = OSAllocatedUnfairLock<Process?>(initialState: nil)

        return AsyncThrowingStream { continuation in
            let task = Task.detached {
                // Write temp MCP config if approval or capabilities are enabled
                var mcpConfigPath: String?
                if let socketPath = approvalSocketPath {
                    mcpConfigPath = Self.writeMCPConfig(socketPath: socketPath, capabilities: enabledCapabilities, workingDirectory: cwd.path)
                }
                defer {
                    if let configPath = mcpConfigPath {
                        try? FileManager.default.removeItem(atPath: configPath)
                    }
                }

                do {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: path)
                    process.arguments = Self.buildArguments(
                        message: message, modelAlias: alias, sessionId: sessionId,
                        appendSystemPrompt: appendSystemPrompt,
                        mcpConfigPath: mcpConfigPath,
                        capabilityConfigs: enabledCapabilities
                    )

                    // Use the project's root directory so the CLI can see project files,
                    // or fall back to a temp directory for scratchpad sessions.
                    process.currentDirectoryURL = cwd
                    Self.logger.debug("Launching CLI with cwd: \(cwd.path, privacy: .public)")

                    let stdout = Pipe()
                    let stderr = Pipe()
                    process.standardOutput = stdout
                    process.standardError = stderr

                    try process.run()
                    processLock.withLock { $0 = process }

                    let handle = stdout.fileHandleForReading
                    var activeToolBlocks: [Int: String] = [:]
                    var receivedResult = false
                    let decoder = JSONDecoder()

                    for try await line in handle.bytes.lines {
                        if Task.isCancelled { break }

                        guard let data = line.data(using: .utf8) else { continue }

                        // Peek at the type field
                        guard let envelope = try? decoder.decode(CLIMessage.self, from: data) else {
                            Self.logger.warning("Failed to decode CLI message: \(line, privacy: .public)")
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
                                Self.handleStreamEvent(
                                    streamEvent.event,
                                    activeToolBlocks: &activeToolBlocks,
                                    continuation: continuation
                                )
                            }

                        case "result":
                            receivedResult = true
                            if let result = try? decoder.decode(CLIResult.self, from: data) {
                                let usage = TokenUsage(
                                    inputTokens: result.usage?.inputTokens ?? 0,
                                    outputTokens: result.usage?.outputTokens ?? 0
                                )
                                if result.isError == true {
                                    let message = result.result
                                        ?? result.subtype
                                        ?? "The CLI returned an error with no details."
                                    Self.logger.error("CLI result error: subtype=\(result.subtype ?? "nil", privacy: .public) result=\(result.result ?? "nil", privacy: .public)")
                                    continuation.yield(.error(.cliError(message)))
                                } else {
                                    continuation.yield(.messageComplete(usage))
                                }
                            }

                        case "user":
                            if let userMsg = try? decoder.decode(CLIUserMessage.self, from: data) {
                                for block in userMsg.message.content
                                    where block.type == "tool_result" {
                                    if let toolId = block.toolUseId {
                                        let output = block.content?.text ?? ""
                                        continuation.yield(.toolResultReceived(id: toolId, output: output))
                                    }
                                }
                            }

                        default:
                            break
                        }
                    }

                    process.waitUntilExit()

                    let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
                    let stderrText = String(data: stderrData, encoding: .utf8) ?? ""
                    let exitCode = Int(process.terminationStatus)

                    if !stderrText.isEmpty {
                        Self.logger.warning("CLI stderr: \(stderrText, privacy: .public)")
                    }

                    if exitCode != 0 && !Task.isCancelled && !receivedResult {
                        continuation.finish(throwing: EngineError.processFailure(
                            exitCode: exitCode,
                            stderr: stderrText
                        ))
                    } else {
                        Self.logger.debug("CLI process exited with code \(exitCode)")
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
        activeToolBlocks: inout [Int: String],
        continuation: AsyncThrowingStream<StreamEvent, Error>.Continuation
    ) {
        switch event.type {
        case "content_block_start":
            if event.contentBlock?.type == "thinking" {
                continuation.yield(.thinkingStarted)
            } else if event.contentBlock?.type == "tool_use",
                      let id = event.contentBlock?.id,
                      let name = event.contentBlock?.name,
                      let index = event.index {
                activeToolBlocks[index] = id
                continuation.yield(.toolUseStarted(id: id, name: name))
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
            case "input_json_delta":
                if let json = delta.partialJson,
                   let index = event.index,
                   let toolId = activeToolBlocks[index] {
                    continuation.yield(.toolInputDelta(id: toolId, json: json))
                }
            default:
                break
            }

        case "content_block_stop":
            if let index = event.index, let toolId = activeToolBlocks[index] {
                continuation.yield(.toolUseFinished(id: toolId))
                activeToolBlocks.removeValue(forKey: index)
            }

        default:
            break
        }
    }

    // MARK: - Argument Building

    /// Tools that are pre-approved and never require user confirmation.
    static let silentTools = ["Read", "Glob", "Grep", "WebSearch", "WebFetch", "Agent"]

    static func buildArguments(
        message: String,
        modelAlias: String,
        sessionId: String?,
        appendSystemPrompt: String? = nil,
        mcpConfigPath: String? = nil,
        capabilityConfigs: [MCPServerConfig] = []
    ) -> [String] {
        var args = [
            "-p",
            "--output-format", "stream-json",
            "--verbose",
            "--include-partial-messages",
            "--model", modelAlias,
        ]

        if let sessionId {
            args += ["--resume", sessionId]
        }

        if let prompt = appendSystemPrompt, !prompt.isEmpty {
            args += ["--append-system-prompt", prompt]
        }

        if let configPath = mcpConfigPath {
            args += ["--mcp-config", configPath]
            args += ["--permission-prompt-tool", "mcp__atelier__approve"]
            for tool in silentTools {
                args += ["--allowedTools", tool]
            }
            // Auto-approve tools from enabled capabilities
            for config in capabilityConfigs {
                for tool in config.autoApproveTools {
                    args += ["--allowedTools", "mcp__\(config.serverName)__\(tool)"]
                }
            }
        }

        // End-of-options marker so the positional prompt is never
        // misinterpreted as a flag (e.g. "-7" or "--help").
        args += ["--", message]

        return args
    }

    /// Locates a bundled helper binary in `Contents/Helpers/`.
    static func bundledHelperPath(named name: String) -> String? {
        let helperURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/\(name)")
        return FileManager.default.isExecutableFile(atPath: helperURL.path)
            ? helperURL.path
            : nil
    }

    /// Locates the bundled MCP approval helper binary.
    static var approvalHelperPath: String? {
        bundledHelperPath(named: "atelier-approval-mcp")
    }

    /// Writes a temporary MCP config JSON file that points the CLI to our approval helper
    /// and any enabled capability servers.
    static func writeMCPConfig(socketPath: String, capabilities: [MCPServerConfig] = [], workingDirectory: String? = nil) -> String? {
        guard let helperPath = approvalHelperPath else {
            logger.warning("Approval helper binary not found in app bundle")
            return nil
        }

        var servers: [String: Any] = [
            "atelier": [
                "command": helperPath,
                "env": [
                    "ATELIER_APPROVAL_SOCKET": socketPath
                ]
            ]
        ]

        for cap in capabilities {
            var env = cap.env
            if let cwd = workingDirectory {
                env["ATELIER_WORKING_DIRECTORY"] = cwd
            }
            var entry: [String: Any] = ["command": cap.command]
            if !cap.args.isEmpty {
                entry["args"] = cap.args
            }
            if !env.isEmpty {
                entry["env"] = env
            }
            servers[cap.serverName] = entry
        }

        let configPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("atelier-mcp-\(UUID().uuidString).json").path
        let config: [String: Any] = ["mcpServers": servers]

        guard let data = try? JSONSerialization.data(withJSONObject: config),
              FileManager.default.createFile(atPath: configPath, contents: data) else {
            logger.warning("Failed to write MCP config to \(configPath, privacy: .public)")
            return nil
        }
        return configPath
    }

    public static var isAvailable: Bool {
        CLIDiscovery.isAvailable
    }
}
