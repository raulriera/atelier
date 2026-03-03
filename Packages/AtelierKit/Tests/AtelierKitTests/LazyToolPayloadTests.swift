import Testing
import Foundation
@testable import AtelierKit

@Suite("Lazy tool payload storage")
struct LazyToolPayloadTests {

    // MARK: - ToolUseEvent cached summaries

    @Suite("ToolUseEvent cached summaries")
    struct CachedSummaries {
        @Test("inputSummary prefers cachedInputSummary when non-empty")
        func inputSummaryPrefersCached() {
            let event = ToolUseEvent(
                id: "t1", name: "Read", inputJSON: "{\"file_path\":\"/a/b.swift\"}",
                status: .completed, cachedInputSummary: "cached-value"
            )
            #expect(event.inputSummary == "cached-value")
        }

        @Test("inputSummary falls back to computing from inputJSON")
        func inputSummaryFallsBackToComputed() {
            let event = ToolUseEvent(id: "t1", name: "Read", inputJSON: "{\"file_path\":\"/a/b.swift\"}", status: .completed)
            #expect(event.inputSummary == "/a/b.swift")
        }

        @Test("resultSummary prefers cachedResultSummary when non-empty")
        func resultSummaryPrefersCached() {
            let event = ToolUseEvent(
                id: "t1", name: "Bash", status: .completed,
                resultOutput: "full output here", cachedResultSummary: "cached-result"
            )
            #expect(event.resultSummary == "cached-result")
        }

        @Test("resultSummary falls back to computing from resultOutput")
        func resultSummaryFallsBackToComputed() {
            let event = ToolUseEvent(id: "t1", name: "Bash", status: .completed, resultOutput: "hello world")
            #expect(event.resultSummary == "hello world")
        }

        @Test("Codable round-trip preserves cached summaries")
        func codableRoundTripPreservesCachedSummaries() throws {
            let event = ToolUseEvent(
                id: "t1", name: "Read", inputJSON: "",
                status: .completed, resultOutput: "",
                cachedInputSummary: "/src/main.swift",
                cachedResultSummary: "file contents..."
            )
            let data = try JSONEncoder().encode(event)
            let decoded = try JSONDecoder().decode(ToolUseEvent.self, from: data)
            #expect(decoded.cachedInputSummary == "/src/main.swift")
            #expect(decoded.cachedResultSummary == "file contents...")
        }

        @Test("Legacy JSON without cached fields decodes to empty strings")
        func legacyJSONDecodesCachedFieldsAsEmpty() throws {
            let json = """
            {"id":"t1","name":"Read","inputJSON":"{}","status":"completed","resultOutput":"data"}
            """
            let event = try JSONDecoder().decode(ToolUseEvent.self, from: Data(json.utf8))
            #expect(event.cachedInputSummary == "")
            #expect(event.cachedResultSummary == "")
        }
    }

    // MARK: - hasResultOutput

    @Suite("hasResultOutput")
    struct HasResultOutput {
        @Test("True when resultOutput is populated")
        func trueWithResultOutput() {
            let event = ToolUseEvent(id: "t1", name: "Bash", status: .completed, resultOutput: "output")
            #expect(event.hasResultOutput)
        }

        @Test("True when cachedResultSummary is populated (lightweight mode)")
        func trueWithCachedSummary() {
            let event = ToolUseEvent(
                id: "t1", name: "Bash", status: .completed,
                resultOutput: "", cachedResultSummary: "cached"
            )
            #expect(event.hasResultOutput)
        }

        @Test("False when both are empty")
        func falseWhenBothEmpty() {
            let event = ToolUseEvent(id: "t1", name: "Bash", status: .completed)
            #expect(!event.hasResultOutput)
        }
    }

    // MARK: - DiskSessionPersistence two-file storage

    @Suite("Disk two-file storage")
    struct DiskTwoFileStorage {
        private func makeTempDir() throws -> URL {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        }

        @Test("Save writes lightweight main file with cached summaries")
        func saveWritesLightweightMainFile() async throws {
            let dir = try makeTempDir()
            let persistence = DiskSessionPersistence(baseDirectory: dir)

            let toolEvent = ToolUseEvent(
                id: "toolu_1", name: "Read",
                inputJSON: "{\"file_path\":\"/src/main.swift\"}",
                status: .completed,
                resultOutput: "func main() { print(\"hello\") }"
            )
            let items = [
                TimelineItem(content: .userMessage(UserMessage(text: "Read this"))),
                TimelineItem(content: .toolUse(toolEvent)),
            ]
            let snapshot = SessionSnapshot(sessionId: "s1", items: items)
            try await persistence.save(snapshot)

            // Load the main file and verify tool stubs
            let loaded = try #require(try await persistence.load(id: "s1"))
            let tool = try #require(loaded.items[1].content.toolUse)
            #expect(tool.inputJSON.isEmpty)
            #expect(tool.resultOutput.isEmpty)
            #expect(tool.cachedInputSummary == "/src/main.swift")
            #expect(!tool.cachedResultSummary.isEmpty)
        }

        @Test("loadToolPayloads returns full data from sidecar")
        func loadToolPayloadsReturnsFullData() async throws {
            let dir = try makeTempDir()
            let persistence = DiskSessionPersistence(baseDirectory: dir)

            let toolEvent = ToolUseEvent(
                id: "toolu_1", name: "Bash",
                inputJSON: "{\"command\":\"ls -la\"}",
                status: .completed,
                resultOutput: "total 42\n-rw-r--r-- 1 user staff 100 file.txt"
            )
            let snapshot = SessionSnapshot(
                sessionId: "s2",
                items: [TimelineItem(content: .toolUse(toolEvent))]
            )
            try await persistence.save(snapshot)

            let payloads = try await persistence.loadToolPayloads(sessionId: "s2")
            let payload = try #require(payloads["toolu_1"])
            #expect(payload.inputJSON == "{\"command\":\"ls -la\"}")
            #expect(payload.resultOutput == "total 42\n-rw-r--r-- 1 user staff 100 file.txt")
        }

        @Test("Delete removes both main and sidecar files")
        func deleteRemovesBothFiles() async throws {
            let dir = try makeTempDir()
            let persistence = DiskSessionPersistence(baseDirectory: dir)

            let toolEvent = ToolUseEvent(
                id: "toolu_1", name: "Read",
                inputJSON: "{\"file_path\":\"a.swift\"}",
                status: .completed,
                resultOutput: "content"
            )
            let snapshot = SessionSnapshot(
                sessionId: "s3",
                items: [TimelineItem(content: .toolUse(toolEvent))]
            )
            try await persistence.save(snapshot)

            let manager = FileManager.default
            #expect(manager.fileExists(atPath: dir.appendingPathComponent("s3.json").path))
            #expect(manager.fileExists(atPath: dir.appendingPathComponent("s3-payloads.json").path))

            await persistence.delete(id: "s3")
            #expect(!manager.fileExists(atPath: dir.appendingPathComponent("s3.json").path))
            #expect(!manager.fileExists(atPath: dir.appendingPathComponent("s3-payloads.json").path))
        }

        @Test("No sidecar created when no tools have payloads")
        func noSidecarWithoutToolPayloads() async throws {
            let dir = try makeTempDir()
            let persistence = DiskSessionPersistence(baseDirectory: dir)

            let snapshot = SessionSnapshot(
                sessionId: "s4",
                items: [TimelineItem(content: .userMessage(UserMessage(text: "Hi")))]
            )
            try await persistence.save(snapshot)

            let manager = FileManager.default
            #expect(manager.fileExists(atPath: dir.appendingPathComponent("s4.json").path))
            #expect(!manager.fileExists(atPath: dir.appendingPathComponent("s4-payloads.json").path))
        }

        @Test("Sidecar files excluded from session listing")
        func sidecarExcludedFromListing() async throws {
            let dir = try makeTempDir()
            let persistence = DiskSessionPersistence(baseDirectory: dir)

            let toolEvent = ToolUseEvent(
                id: "toolu_1", name: "Read",
                inputJSON: "{\"file_path\":\"a.swift\"}",
                status: .completed,
                resultOutput: "data"
            )
            let snapshot = SessionSnapshot(
                sessionId: "s5",
                items: [TimelineItem(content: .toolUse(toolEvent))]
            )
            try await persistence.save(snapshot)

            let metadata = await persistence.list()
            #expect(metadata.count == 1)
            #expect(metadata[0].sessionId == "s5")
        }
    }

    // MARK: - Session.populateToolPayload

    @Suite("Session.populateToolPayload")
    struct PopulateToolPayload {
        @Test("Replaces stubs with full data and clears cached summaries")
        @MainActor func replacesStubsWithFullData() throws {
            let lightweightEvent = ToolUseEvent(
                id: "toolu_1", name: "Read",
                inputJSON: "", status: .completed, resultOutput: "",
                cachedInputSummary: "/src/main.swift",
                cachedResultSummary: "func main()..."
            )
            let snapshot = SessionSnapshot(
                sessionId: "test",
                items: [
                    TimelineItem(content: .userMessage(UserMessage(text: "Read this"))),
                    TimelineItem(content: .toolUse(lightweightEvent)),
                ]
            )
            let session = Session.restore(from: snapshot)

            session.populateToolPayload(
                toolId: "toolu_1",
                inputJSON: "{\"file_path\":\"/src/main.swift\"}",
                resultOutput: "func main() { print(\"hello\") }"
            )

            let event = try #require(session.items[1].content.toolUse)
            #expect(event.inputJSON == "{\"file_path\":\"/src/main.swift\"}")
            #expect(event.resultOutput == "func main() { print(\"hello\") }")
            #expect(event.cachedInputSummary.isEmpty)
            #expect(event.cachedResultSummary.isEmpty)
        }

        @Test("No-op for unknown tool ID")
        @MainActor func noOpForUnknownToolId() throws {
            let snapshot = SessionSnapshot(
                sessionId: "test",
                items: [
                    TimelineItem(content: .toolUse(ToolUseEvent(id: "toolu_1", name: "Read", status: .completed))),
                ]
            )
            let session = Session.restore(from: snapshot)
            session.populateToolPayload(toolId: "toolu_unknown", inputJSON: "x", resultOutput: "y")
            let event = try #require(session.items[0].content.toolUse)
            #expect(event.inputJSON == "")
        }
    }
}
