import Testing
import Foundation
@testable import AtelierKit

// MARK: - Mock engine

/// A controllable engine that yields events from a provided array.
private struct MockEngine: ConversationEngine {
    var events: [StreamEvent]

    func send(
        message: String,
        model: ModelConfiguration,
        sessionId: String?,
        workingDirectory: URL?,
        appendSystemPrompt: String?,
        approvalSocketPath: String?,
        enabledCapabilities: [EnabledCapability],
        allowedReadPaths: [String]
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        let captured = events
        return AsyncThrowingStream { continuation in
            for event in captured {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }
}

/// An engine that records what was sent to it.
/// Safety: Only accessed from @MainActor test functions.
@MainActor
private final class SpyEngine: ConversationEngine, @unchecked Sendable {
    var sentMessages: [String] = []
    var sentModels: [ModelConfiguration] = []
    var sentAllowedReadPaths: [[String]] = []
    var events: [StreamEvent] = []

    nonisolated func send(
        message: String,
        model: ModelConfiguration,
        sessionId: String?,
        workingDirectory: URL?,
        appendSystemPrompt: String?,
        approvalSocketPath: String?,
        enabledCapabilities: [EnabledCapability],
        allowedReadPaths: [String]
    ) -> AsyncThrowingStream<StreamEvent, Error> {
        // Capture events before entering nonisolated context
        let captured = MainActor.assumeIsolated {
            sentMessages.append(message)
            sentModels.append(model)
            sentAllowedReadPaths.append(allowedReadPaths)
            return events
        }
        return AsyncThrowingStream { continuation in
            for event in captured {
                continuation.yield(event)
            }
            continuation.finish()
        }
    }
}

// MARK: - Helpers

@MainActor
private func makeController(
    engine: any ConversationEngine = MockEngine(events: []),
    persistence: SessionPersistence? = nil,
    workingDirectory: URL? = nil
) async -> ConversationController {
    let store = CapabilityStore()
    let p = persistence ?? InMemorySessionPersistence()
    return ConversationController(
        engine: engine,
        capabilityStore: store,
        sessionPersistence: p,
        workingDirectory: workingDirectory
    )
}

// MARK: - Tests

@Suite("ConversationController")
struct ConversationControllerTests {

    @Suite("Sending messages")
    struct SendingMessages {

        @Test("sendMessage trims whitespace and ignores blank input")
        @MainActor func ignoresBlankMessages() async {
            let spy = SpyEngine()
            let controller = await makeController(engine: spy)
            controller.sendMessage("   ")
            #expect(spy.sentMessages.isEmpty)
            #expect(controller.session.items.isEmpty)
        }

        @Test("sendMessage appends user message and begins assistant")
        @MainActor func appendsUserAndBeginsAssistant() async throws {
            let engine = MockEngine(events: [
                .messageComplete(TokenUsage(inputTokens: 10, outputTokens: 5))
            ])
            let controller = await makeController(engine: engine)
            controller.sendMessage("Hello")

            #expect(controller.session.items.count >= 1)
            let userMsg = try #require(controller.session.items.first?.content.userMessage)
            #expect(userMsg.text == "Hello")
        }

        @Test("sendMessage queues when already streaming")
        @MainActor func queuesWhenStreaming() async {
            let engine = MockEngine(events: [])
            let controller = await makeController(engine: engine)

            // Manually begin streaming to simulate in-progress
            controller.session.appendUserMessage("First")
            controller.session.beginAssistantMessage()
            #expect(controller.session.isStreaming)

            controller.sendMessage("Queued message")
            #expect(controller.session.pendingMessages.contains("Queued message"))
        }
    }

    @Suite("Stream event handling")
    struct StreamEvents {

        @Test("Text deltas accumulate in the session", .timeLimit(.minutes(1)))
        @MainActor func textDeltasAccumulate() async throws {
            let engine = MockEngine(events: [
                .sessionStarted("test-session"),
                .textDelta("Hello"),
                .textDelta(" world"),
                .messageComplete(TokenUsage(inputTokens: 10, outputTokens: 5))
            ])
            let controller = await makeController(engine: engine)
            controller.sendMessage("Hi")

            // Poll until streaming completes
            for _ in 0..<40 {
                if !controller.session.isStreaming { break }
                try await Task.sleep(for: .milliseconds(25))
            }

            #expect(controller.session.sessionId == "test-session")
            #expect(!controller.session.isStreaming)

            let assistant = try #require(controller.session.items.last?.content.assistantMessage)
            #expect(assistant.text == "Hello world")
        }

        @Test("Tool use events flow through correctly", .timeLimit(.minutes(1)))
        @MainActor func toolUseEvents() async throws {
            let engine = MockEngine(events: [
                .toolUseStarted(id: "t1", name: "Read"),
                .toolInputDelta(id: "t1", json: "{\"path\":\"/tmp\"}"),
                .toolUseFinished(id: "t1"),
                .toolResultReceived(id: "t1", output: "file contents", isError: false),
                .messageComplete(TokenUsage())
            ])
            let controller = await makeController(engine: engine)
            controller.sendMessage("Read a file")

            for _ in 0..<40 {
                if !controller.session.isStreaming { break }
                try await Task.sleep(for: .milliseconds(25))
            }

            let toolItem = try #require(controller.session.items.first(where: {
                if case .toolUse = $0.content { return true }
                return false
            }))
            let tool = try #require(toolItem.content.toolUse)
            #expect(tool.name == "Read")
            #expect(tool.status == .completed)
        }

        @Test("Error events set session error state", .timeLimit(.minutes(1)))
        @MainActor func errorEvents() async throws {
            let engine = MockEngine(events: [
                .error(.cliError("Something went wrong")),
            ])
            let controller = await makeController(engine: engine)
            controller.sendMessage("Fail")

            for _ in 0..<40 {
                if !controller.session.isStreaming { break }
                try await Task.sleep(for: .milliseconds(25))
            }

            let systemItem = try #require(controller.session.items.last(where: {
                if case .system = $0.content { return true }
                return false
            }))
            let event = try #require(systemItem.content.system)
            #expect(event.kind == .error)
        }
    }

    @Suite("Stop generation")
    struct StopGeneration {

        @Test("stopGeneration clears streaming state")
        @MainActor func clearsStreamingState() async {
            let controller = await makeController()
            controller.session.appendUserMessage("Hello")
            controller.session.beginAssistantMessage()
            controller.session.enqueuePendingMessage("Queued")

            #expect(controller.session.isStreaming)
            controller.stopGeneration()
            #expect(!controller.session.isStreaming)
            #expect(controller.session.pendingMessages.isEmpty)
        }
    }

    @Suite("Approval handling")
    struct Approvals {

        @Test("handleApprovalDecision resolves approval in session")
        @MainActor func resolvesApproval() async throws {
            let controller = await makeController()
            controller.session.beginApproval(id: "a1", toolName: "Bash", inputJSON: "{}")

            controller.handleApprovalDecision(id: "a1", toolName: "Bash", decision: .allow)

            let item = try #require(controller.session.items.last(where: {
                if case .approval = $0.content { return true }
                return false
            }))
            let approval = try #require(item.content.approval)
            #expect(approval.status == .approved)
        }

        @Test("allowForSession tracks tool name for auto-approval")
        @MainActor func tracksSessionApproval() async {
            let controller = await makeController()
            controller.session.beginApproval(id: "a1", toolName: "Bash", inputJSON: "{}")

            controller.handleApprovalDecision(id: "a1", toolName: "Bash", decision: .allowForSession)

            #expect(controller.sessionApprovedTools.contains("Bash"))
        }
    }

    @Suite("Ask user handling")
    struct AskUser {

        @Test("handleAskUserResponse resolves ask-user event")
        @MainActor func resolvesAskUser() async throws {
            let controller = await makeController()
            controller.session.beginAskUser(
                id: "q1",
                question: "Pick one",
                options: [
                    AskUserEvent.Option(label: "A", description: nil),
                    AskUserEvent.Option(label: "B", description: nil)
                ]
            )

            controller.handleAskUserResponse(id: "q1", selectedIndex: 1)

            let item = try #require(controller.session.items.last(where: {
                if case .askUser = $0.content { return true }
                return false
            }))
            let event = try #require(item.content.askUser)
            #expect(event.status == .answered)
            #expect(event.selectedIndex == 1)
        }
    }

    @Suite("New conversation")
    struct NewConversation {

        @Test("startNewConversation resets session and clears approved tools")
        @MainActor func resetsSession() async {
            let controller = await makeController()
            controller.session.appendUserMessage("Old message")
            controller.session.beginApproval(id: "a1", toolName: "Bash", inputJSON: "{}")
            controller.handleApprovalDecision(id: "a1", toolName: "Bash", decision: .allowForSession)

            controller.startNewConversation()

            #expect(controller.session.items.isEmpty)
            #expect(controller.sessionApprovedTools.isEmpty)
        }
    }

    @Suite("Tool payload loading")
    struct ToolPayloads {

        @Test("loadToolPayloadIfNeeded populates tool and removes from cache")
        @MainActor func populatesPayload() async throws {
            let controller = await makeController()
            controller.session.beginToolUse(id: "t1", name: "Read")
            controller.session.finalizeToolInput(id: "t1")
            controller.session.completeToolUse(id: "t1")

            // Simulate cached payload
            controller.toolPayloads["t1"] = ToolPayload(inputJSON: "{\"path\":\"/tmp\"}", resultOutput: "contents")

            controller.selectedToolEvent = try #require(controller.session.items.compactMap {
                if case .toolUse(let e) = $0.content { return e }
                return nil
            }.first)

            controller.loadToolPayloadIfNeeded(for: "t1")

            #expect(controller.toolPayloads["t1"] == nil)
            let selected = try #require(controller.selectedToolEvent)
            #expect(selected.resultOutput == "contents")
        }

        @Test("loadToolPayloadIfNeeded is a no-op for missing payload")
        @MainActor func noOpForMissingPayload() async {
            let controller = await makeController()
            controller.loadToolPayloadIfNeeded(for: "nonexistent")
            // Should not crash or change state
        }
    }

    @Suite("Model selection")
    struct ModelSelection {

        @Test("Selected model is passed to the engine", .timeLimit(.minutes(1)))
        @MainActor func passesModelToEngine() async throws {
            let spy = SpyEngine()
            spy.events = [.messageComplete(TokenUsage())]
            let controller = await makeController(engine: spy)
            controller.selectedModel = .opus

            controller.sendMessage("Test")

            for _ in 0..<40 {
                if !spy.sentModels.isEmpty { break }
                try await Task.sleep(for: .milliseconds(25))
            }

            let sentModel = try #require(spy.sentModels.first)
            #expect(sentModel.modelId == ModelConfiguration.opus.modelId)
        }
    }

    @Suite("Attachment read paths")
    struct AttachmentReadPaths {

        @Test("Dropped file paths are passed to the engine as allowedReadPaths", .timeLimit(.minutes(1)))
        @MainActor func passesPathsToEngine() async throws {
            let spy = SpyEngine()
            spy.events = [.messageComplete(TokenUsage())]
            let controller = await makeController(engine: spy)

            let attachment = FileAttachment(url: URL(fileURLWithPath: "/Users/someone/Documents/report.pdf"))
            controller.sendMessage("Check this", attachments: [attachment])

            for _ in 0..<40 {
                if !spy.sentAllowedReadPaths.isEmpty { break }
                try await Task.sleep(for: .milliseconds(25))
            }

            let paths = try #require(spy.sentAllowedReadPaths.first)
            let expected = URL(fileURLWithPath: "/Users/someone/Documents/report.pdf").standardizedFileURL.path
            #expect(paths.contains(expected))
        }

        @Test("Multiple attachments across messages accumulate paths", .timeLimit(.minutes(1)))
        @MainActor func accumulatesPathsAcrossMessages() async throws {
            let spy = SpyEngine()
            spy.events = [.messageComplete(TokenUsage())]
            let controller = await makeController(engine: spy)

            let first = FileAttachment(url: URL(fileURLWithPath: "/tmp/a.txt"))
            controller.sendMessage("First", attachments: [first])

            for _ in 0..<40 {
                if !controller.session.isStreaming { break }
                try await Task.sleep(for: .milliseconds(25))
            }

            let second = FileAttachment(url: URL(fileURLWithPath: "/tmp/b.txt"))
            controller.sendMessage("Second", attachments: [second])

            for _ in 0..<40 {
                if spy.sentAllowedReadPaths.count >= 2 { break }
                try await Task.sleep(for: .milliseconds(25))
            }

            // Second call should contain both paths
            let paths = try #require(spy.sentAllowedReadPaths.last)
            let expectedA = URL(fileURLWithPath: "/tmp/a.txt").standardizedFileURL.path
            let expectedB = URL(fileURLWithPath: "/tmp/b.txt").standardizedFileURL.path
            #expect(paths.contains(expectedA))
            #expect(paths.contains(expectedB))
        }

        @Test("Text-only message passes empty allowedReadPaths", .timeLimit(.minutes(1)))
        @MainActor func textOnlyHasEmptyPaths() async throws {
            let spy = SpyEngine()
            spy.events = [.messageComplete(TokenUsage())]
            let controller = await makeController(engine: spy)

            controller.sendMessage("Just text")

            for _ in 0..<40 {
                if !spy.sentAllowedReadPaths.isEmpty { break }
                try await Task.sleep(for: .milliseconds(25))
            }

            let paths = try #require(spy.sentAllowedReadPaths.first)
            #expect(paths.isEmpty)
        }
    }

    @Suite("Project fingerprinting")
    struct Fingerprinting {

        private func makeTempProject(withContextFile: Bool = false) throws -> URL {
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("CCTests-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

            // Add some files so the fingerprint has content
            try "revenue".write(to: dir.appendingPathComponent("data.csv"), atomically: true, encoding: .utf8)
            try "notes".write(to: dir.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

            if withContextFile {
                let atelierDir = dir.appendingPathComponent(".atelier", isDirectory: true)
                try FileManager.default.createDirectory(at: atelierDir, withIntermediateDirectories: true)
                try "Custom context".write(
                    to: atelierDir.appendingPathComponent("context.md"),
                    atomically: true,
                    encoding: .utf8
                )
            }

            return dir
        }

        private func cleanup(_ url: URL) {
            try? FileManager.default.removeItem(at: url)
        }

        @Test("checkAvailability triggers background fingerprinting when no context.md exists", .timeLimit(.minutes(1)))
        @MainActor func triggersFingerprinting() async throws {
            let dir = try makeTempProject()
            defer { cleanup(dir) }

            let controller = await makeController(workingDirectory: dir)
            controller.checkAvailability()

            let contextPath = dir
                .appendingPathComponent(".atelier", isDirectory: true)
                .appendingPathComponent("context.md")

            // Poll for the file — the detached fingerprint task may take
            // variable time depending on system load.
            for _ in 0..<50 {
                if FileManager.default.fileExists(atPath: contextPath.path) { break }
                try await Task.sleep(for: .milliseconds(100))
            }

            #expect(FileManager.default.fileExists(atPath: contextPath.path), "context.md should be created by fingerprinting within 5 seconds")

            let content = try String(contentsOf: contextPath, encoding: .utf8)
            #expect(content.contains("# Project Context"))
        }

        @Test("checkAvailability does not overwrite existing context.md", .timeLimit(.minutes(1)))
        @MainActor func doesNotOverwriteExisting() async throws {
            let dir = try makeTempProject(withContextFile: true)
            defer { cleanup(dir) }

            let controller = await makeController(workingDirectory: dir)
            controller.checkAvailability()

            // Short wait — the detached task returns immediately when the file exists.
            try await Task.sleep(for: .milliseconds(200))

            let contextPath = dir
                .appendingPathComponent(".atelier", isDirectory: true)
                .appendingPathComponent("context.md")
            let content = try String(contentsOf: contextPath, encoding: .utf8)
            #expect(content == "Custom context")
        }

        @Test("checkAvailability returns immediately without blocking")
        @MainActor func nonBlocking() async throws {
            let dir = try makeTempProject()
            defer { cleanup(dir) }

            let controller = await makeController(workingDirectory: dir)

            // checkAvailability is synchronous — it must return immediately
            // even when fingerprinting is needed
            controller.checkAvailability()

            // If we get here, it didn't block
            #expect(!controller.session.isStreaming)
        }
    }

    @Suite("Capability health")
    struct CapabilityHealth {

        @Test("Tool result errors are tracked by capability health monitor", .timeLimit(.minutes(1)))
        @MainActor func tracksErrors() async throws {
            let engine = MockEngine(events: [
                .toolUseStarted(id: "t1", name: "mcp__mail__send"),
                .toolInputDelta(id: "t1", json: "{}"),
                .toolUseFinished(id: "t1"),
                .toolResultReceived(id: "t1", output: "error", isError: true),
                .toolResultReceived(id: "t1", output: "error again", isError: true),
                .toolResultReceived(id: "t1", output: "error third", isError: true),
                .messageComplete(TokenUsage())
            ])
            let controller = await makeController(engine: engine)
            controller.sendMessage("Send email")

            for _ in 0..<40 {
                if !controller.session.isStreaming { break }
                try await Task.sleep(for: .milliseconds(25))
            }

            // MCPToolMetadata extracts "mail" from "mcp__mail__send"
            #expect(controller.capabilityHealthMonitor.health["mail"] == .unavailable)
        }
    }
}
