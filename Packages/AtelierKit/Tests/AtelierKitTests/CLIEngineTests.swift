import Foundation
import Testing
@testable import AtelierKit

@Suite("CLIEngine argument building")
struct CLIEngineTests {

    @Suite("Fresh session")
    struct FreshSession {
        @Test("Never includes --continue or --resume")
        func neverIncludesContinueOrResume() {
            let args = CLIEngine.buildArguments(
                message: "hello", modelAlias: "opus", sessionId: nil
            )
            #expect(!args.contains("--continue"))
            #expect(!args.contains("--resume"))
        }

        @Test("Includes required flags")
        func includesRequiredFlags() {
            let args = CLIEngine.buildArguments(
                message: "hello", modelAlias: "opus", sessionId: nil
            )
            #expect(args.contains("-p"))
            #expect(args.contains("--output-format"))
            #expect(args.contains("stream-json"))
            #expect(args.contains("--model"))
            #expect(args.contains("opus"))
            #expect(args.contains("--include-partial-messages"))
        }

        @Test("Does not include --max-turns")
        func maxTurnsNotPresent() {
            let args = CLIEngine.buildArguments(
                message: "hello", modelAlias: "opus", sessionId: nil
            )
            #expect(!args.contains("--max-turns"))
        }
    }

    @Test("Resume session passes session ID and --resume flag")
    func resumeSessionPassesSessionId() {
        let args = CLIEngine.buildArguments(
            message: "follow up", modelAlias: "sonnet", sessionId: "abc-123"
        )
        #expect(args.contains("--resume"))
        #expect(args.contains("abc-123"))
        #expect(!args.contains("--continue"))
    }

    @Test("Message is passed as positional argument after end-of-options marker")
    func messageIsPassedAfterEndOfOptions() throws {
        let msg = "What is 2+2?"
        let args = CLIEngine.buildArguments(
            message: msg, modelAlias: "haiku", sessionId: nil
        )
        let ddIdx = try #require(args.firstIndex(of: "--"), "-- marker missing")
        #expect(args[ddIdx + 1] == msg)
        #expect(args.last == msg)
    }

    @Test("Dash-prefixed message is not misinterpreted as a flag")
    func dashPrefixedMessageSafe() throws {
        let args = CLIEngine.buildArguments(
            message: "-7", modelAlias: "haiku", sessionId: nil
        )
        let ddIdx = try #require(args.firstIndex(of: "--"), "-- marker missing")
        #expect(args[ddIdx + 1] == "-7")
    }

    @Test("Model alias is passed verbatim after --model flag")
    func modelAliasIsPassedVerbatim() throws {
        let args = CLIEngine.buildArguments(
            message: "hi", modelAlias: "haiku", sessionId: nil
        )
        let mIdx = try #require(args.firstIndex(of: "--model"), "--model flag missing")
        #expect(args[mIdx + 1] == "haiku")
    }

    @Suite("Approval parameters")
    struct ApprovalParameters {
        @Test("MCP config path adds --mcp-config, --permission-prompt-tool, and --allowedTools flags")
        func mcpConfigAddsFlags() throws {
            let args = CLIEngine.buildArguments(
                message: "hello", modelAlias: "opus", sessionId: nil,
                mcpConfigPath: "/tmp/test-config.json"
            )
            let mcpIdx = try #require(
                args.firstIndex(of: "--mcp-config"),
                "--mcp-config flag missing"
            )
            #expect(args[mcpIdx + 1] == "/tmp/test-config.json")

            #expect(args.contains("--permission-prompt-tool"))
            let permIdx = try #require(args.firstIndex(of: "--permission-prompt-tool"))
            #expect(args[permIdx + 1] == "mcp__atelier__approve")

            #expect(args.contains("--allowedTools"))
        }

        @Test("Silent tools are pre-approved via --allowedTools")
        func silentToolsPreApproved() {
            let args = CLIEngine.buildArguments(
                message: "hello", modelAlias: "opus", sessionId: nil,
                mcpConfigPath: "/tmp/test-config.json"
            )
            for tool in CLIEngine.silentTools {
                let indices = args.indices.filter { args[$0] == "--allowedTools" }
                let toolFollows = indices.contains { args.indices.contains($0 + 1) && args[$0 + 1] == tool }
                #expect(toolFollows, "Expected \(tool) to be listed after --allowedTools")
            }
        }

        @Test("WebFetch and Agent are not in silentTools")
        func webFetchAndAgentExcluded() {
            #expect(!CLIEngine.silentTools.contains("WebFetch"))
            #expect(!CLIEngine.silentTools.contains("Agent"))
        }

        @Test("Read, Glob, Grep are not blanket-allowed")
        func fileToolsNotBlanketAllowed() {
            let args = CLIEngine.buildArguments(
                message: "hello", modelAlias: "opus", sessionId: nil,
                mcpConfigPath: "/tmp/test-config.json"
            )
            // These should only appear as scoped rules, not bare tool names
            let allowedValues = values(after: "--allowedTools", in: args)
            #expect(!allowedValues.contains("Read"))
            #expect(!allowedValues.contains("Glob"))
            #expect(!allowedValues.contains("Grep"))
        }

        @Test("No MCP config omits all approval flags")
        func noMcpConfigOmitsFlags() {
            let args = CLIEngine.buildArguments(
                message: "hello", modelAlias: "opus", sessionId: nil,
                mcpConfigPath: nil
            )
            #expect(!args.contains("--mcp-config"))
            #expect(!args.contains("--permission-prompt-tool"))
            #expect(!args.contains("--allowedTools"))
        }
    }

    @Suite("Filesystem boundary")
    struct FilesystemBoundary {
        @Test("Scoped allow rules generated for working directory")
        func scopedAllowRulesForWorkingDir() {
            let args = CLIEngine.buildArguments(
                message: "hello", modelAlias: "opus", sessionId: nil,
                mcpConfigPath: "/tmp/test-config.json",
                workingDirectoryPath: "/Users/test/project"
            )
            let allowedValues = values(after: "--allowedTools", in: args)
            #expect(allowedValues.contains("Read(/Users/test/project/*)"))
            #expect(allowedValues.contains("Glob(/Users/test/project/*)"))
            #expect(allowedValues.contains("Grep(/Users/test/project/*)"))
        }

        @Test("scopedRoot normalizes path")
        func scopedRootNormalizes() {
            let root = CLIEngine.scopedRoot(workingDirectoryPath: "/Users/test/other/../other")
            #expect(root == "/Users/test/other")
        }

        @Test("scopedRoot returns nil when no working directory")
        func scopedRootNilWithoutCwd() {
            #expect(CLIEngine.scopedRoot(workingDirectoryPath: nil) == nil)
        }

        @Test("Sensitive deny rules use absolute paths")
        func sensitiveDenyRulesUseAbsolutePaths() {
            let rules = CLIEngine.sensitivePathDenyRules()
            // All deny rules should contain absolute paths, not ~
            for rule in rules {
                #expect(!rule.contains("~"), "Deny rule should not contain ~: \(rule)")
            }
            // Should contain the real home directory path
            let home = CLIDiscovery.realHomeDirectory
            let hasAbsolutePath = rules.contains { $0.contains(home) }
            #expect(hasAbsolutePath, "Deny rules should contain absolute home path")
        }
    }

    @Suite("Attachment read paths")
    struct AttachmentReadPaths {
        @Test("allowedReadPaths emit --allowedTools Read(//path) for each file")
        func emitsReadRulesForEachPath() {
            let args = CLIEngine.buildArguments(
                message: "check this", modelAlias: "opus", sessionId: nil,
                mcpConfigPath: "/tmp/test-config.json",
                allowedReadPaths: [
                    "/Users/someone/Documents/report.pdf",
                    "/Users/someone/Desktop/photo.png"
                ]
            )
            let allowedValues = values(after: "--allowedTools", in: args)
            // Double-slash prefix marks absolute filesystem paths (single / is project-relative)
            #expect(allowedValues.contains("Read(//Users/someone/Documents/report.pdf)"))
            #expect(allowedValues.contains("Read(//Users/someone/Desktop/photo.png)"))
        }

        @Test("allowedReadPaths are omitted without MCP config")
        func omittedWithoutMcpConfig() {
            let args = CLIEngine.buildArguments(
                message: "check this", modelAlias: "opus", sessionId: nil,
                mcpConfigPath: nil,
                allowedReadPaths: ["/Users/someone/file.txt"]
            )
            let allowedValues = values(after: "--allowedTools", in: args)
            #expect(!allowedValues.contains { $0.hasPrefix("Read(") })
        }

        @Test("allowedReadPaths are independent of project-scoped rules")
        func independentOfProjectRules() {
            let args = CLIEngine.buildArguments(
                message: "check this", modelAlias: "opus", sessionId: nil,
                mcpConfigPath: "/tmp/test-config.json",
                workingDirectoryPath: "/Users/test/project",
                allowedReadPaths: ["/Users/someone/Documents/outside.pdf"]
            )
            let allowedValues = values(after: "--allowedTools", in: args)
            // Both project-scoped and attachment-specific rules present
            #expect(allowedValues.contains("Read(/Users/test/project/*)"))
            #expect(allowedValues.contains("Read(//Users/someone/Documents/outside.pdf)"))
        }
    }

    @Suite("Append system prompt")
    struct AppendSystemPrompt {
        @Test("Non-empty value adds --append-system-prompt flag")
        func appendSystemPromptAddsFlag() throws {
            let args = CLIEngine.buildArguments(
                message: "hi", modelAlias: "opus", sessionId: nil,
                appendSystemPrompt: "Extra context here"
            )
            let idx = try #require(
                args.firstIndex(of: "--append-system-prompt"),
                "--append-system-prompt flag missing"
            )
            #expect(args[idx + 1] == "Extra context here")
        }

        @Test(
            "Nil or empty value omits --append-system-prompt flag",
            arguments: [nil, ""] as [String?]
        )
        func omitsFlagForNilOrEmpty(value: String?) {
            let args = CLIEngine.buildArguments(
                message: "hi", modelAlias: "opus", sessionId: nil,
                appendSystemPrompt: value
            )
            #expect(!args.contains("--append-system-prompt"))
        }
    }
}

@Suite("Pipe reading")
struct PipeReadingTests {

    @Test("Stdout completes when stderr is large")
    func stdoutCompletesWithLargeStderr() async throws {
        // Launches a subprocess that writes >64 KB to stderr (exceeding the
        // macOS pipe buffer) while also writing to stdout. If stderr isn't
        // drained concurrently, the process deadlocks and the test times out.
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", """
            python3 -c "import sys; sys.stderr.write('x' * 102400); sys.stderr.flush(); print('done')"
            """]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()

        let stderrHandle = stderr.fileHandleForReading
        let stderrTask = Task.detached { () -> Data in
            stderrHandle.readDataToEndOfFile()
        }

        let fd = stdout.fileHandleForReading.fileDescriptor
        var lines: [String] = []
        for await line in CLIEngine.lines(from: fd) {
            lines.append(line)
        }

        process.waitUntilExit()
        let stderrData = await stderrTask.value

        #expect(process.terminationStatus == 0)
        #expect(lines == ["done"])
        #expect(stderrData.count == 102_400, "All stderr bytes should be captured")
    }

    @Test("Lines reader handles multiple lines")
    func linesReaderMultipleLines() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", "echo 'line1'; echo 'line2'; echo 'line3'"]

        let stdout = Pipe()
        process.standardOutput = stdout

        try process.run()

        let fd = stdout.fileHandleForReading.fileDescriptor
        var lines: [String] = []
        for await line in CLIEngine.lines(from: fd) {
            lines.append(line)
        }

        process.waitUntilExit()
        #expect(lines == ["line1", "line2", "line3"])
    }

    @Test("Lines reader handles empty output")
    func linesReaderEmptyOutput() async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", "true"]

        let stdout = Pipe()
        process.standardOutput = stdout

        try process.run()

        let fd = stdout.fileHandleForReading.fileDescriptor
        var lines: [String] = []
        for await line in CLIEngine.lines(from: fd) {
            lines.append(line)
        }

        process.waitUntilExit()
        #expect(lines.isEmpty)
    }
}

/// Extracts all values that follow a given flag in an arguments array.
private func values(after flag: String, in args: [String]) -> [String] {
    args.indices.compactMap { i in
        args[i] == flag && args.indices.contains(i + 1) ? args[i + 1] : nil
    }
}
