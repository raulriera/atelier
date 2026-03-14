import Testing
import Foundation
@testable import AtelierKit

@Suite("TimelineItem")
struct TimelineItemTests {

    @Suite("Round-trip encoding")
    struct RoundTrip {
        @Test("User message round-trips through JSON")
        func userMessageRoundTrip() throws {
            let item = TimelineItem(content: .userMessage(UserMessage(text: "Hello")))
            let data = try JSONEncoder().encode(item)
            let decoded = try JSONDecoder().decode(TimelineItem.self, from: data)
            #expect(decoded.id == item.id)
            let msg = try #require(decoded.content.userMessage)
            #expect(msg.text == "Hello")
        }

        @Test("Assistant message round-trips through JSON")
        func assistantMessageRoundTrip() throws {
            let usage = TokenUsage(inputTokens: 10, outputTokens: 25, cacheReadTokens: 5, cacheCreationTokens: 3)
            let assistant = AssistantMessage(text: "Hi there", isComplete: true, usage: usage)
            let item = TimelineItem(content: .assistantMessage(assistant))
            let data = try JSONEncoder().encode(item)
            let decoded = try JSONDecoder().decode(TimelineItem.self, from: data)
            let msg = try #require(decoded.content.assistantMessage)
            #expect(msg.text == "Hi there")
            #expect(msg.isComplete)
            #expect(msg.usage.inputTokens == 10)
            #expect(msg.usage.outputTokens == 25)
            #expect(msg.usage.cacheReadTokens == 5)
            #expect(msg.usage.cacheCreationTokens == 3)
        }

        @Test("System event round-trips through JSON")
        func systemEventRoundTrip() throws {
            let event = SystemEvent(kind: .error, message: "Something went wrong")
            let item = TimelineItem(content: .system(event))
            let data = try JSONEncoder().encode(item)
            let decoded = try JSONDecoder().decode(TimelineItem.self, from: data)
            let evt = try #require(decoded.content.system)
            #expect(evt.kind == .error)
            #expect(evt.message == "Something went wrong")
        }

        @Test("ToolUseEvent round-trips through JSON")
        func toolUseEventRoundTrip() throws {
            let event = ToolUseEvent(id: "toolu_abc", name: "Read", inputJSON: "{\"file_path\":\"test.swift\"}", status: .completed)
            let item = TimelineItem(content: .toolUse(event))
            let data = try JSONEncoder().encode(item)
            let decoded = try JSONDecoder().decode(TimelineItem.self, from: data)
            let evt = try #require(decoded.content.toolUse)
            #expect(evt.id == "toolu_abc")
            #expect(evt.name == "Read")
            #expect(evt.inputJSON == "{\"file_path\":\"test.swift\"}")
            #expect(evt.status == .completed)
        }

        @Test("ToolUseEvent with resultOutput round-trips through JSON")
        func toolUseEventWithResultOutputRoundTrip() throws {
            let event = ToolUseEvent(id: "toolu_abc", name: "Read", inputJSON: "{}", status: .completed, resultOutput: "file contents")
            let item = TimelineItem(content: .toolUse(event))
            let data = try JSONEncoder().encode(item)
            let decoded = try JSONDecoder().decode(TimelineItem.self, from: data)
            let evt = try #require(decoded.content.toolUse)
            #expect(evt.resultOutput == "file contents")
        }

        @Test("Legacy ToolUseEvent without resultOutput decodes as empty string")
        func legacyToolUseEventDecodesResultOutputAsEmpty() throws {
            let json = """
            {"id":"toolu_old","name":"Bash","inputJSON":"{}","status":"completed"}
            """
            let data = Data(json.utf8)
            let event = try JSONDecoder().decode(ToolUseEvent.self, from: data)
            #expect(event.resultOutput == "")
        }

        @Test("Stable identity preserved through encoding")
        func stableIdentity() throws {
            let id = UUID()
            let item = TimelineItem(id: id, content: .userMessage(UserMessage(text: "test")))
            let data = try JSONEncoder().encode(item)
            let decoded = try JSONDecoder().decode(TimelineItem.self, from: data)
            #expect(decoded.id == id)
        }
    }

    @Suite("Input summary")
    struct InputSummary {
        @Test(
            "Extracts known keys from input JSON",
            arguments: zip(
                [
                    ("Read", "{\"file_path\":\"/src/main.swift\"}"),
                    ("Bash", "{\"command\":\"ls -la\"}"),
                    ("Glob", "{\"pattern\":\"**/*.swift\"}"),
                ],
                ["/src/main.swift", "ls -la", "**/*.swift"]
            )
        )
        func extractsKnownKeys(_ input: (name: String, json: String), expected: String) {
            let event = ToolUseEvent(id: "t", name: input.name, inputJSON: input.json)
            #expect(event.inputSummary == expected)
        }

        @Test("Truncates long values to 80 characters")
        func truncatesLongValues() {
            let longPath = String(repeating: "a", count: 100)
            let event = ToolUseEvent(id: "t4", name: "Read", inputJSON: "{\"file_path\":\"\(longPath)\"}")
            #expect(event.inputSummary.count == 80)
            #expect(event.inputSummary.hasSuffix("..."))
        }

        @Test("Returns empty string for invalid JSON")
        func returnsEmptyForInvalidJSON() {
            let event = ToolUseEvent(id: "t5", name: "Read", inputJSON: "not json")
            #expect(event.inputSummary == "")
        }

        @Test("Returns empty string for empty JSON")
        func returnsEmptyForEmptyJSON() {
            let event = ToolUseEvent(id: "t6", name: "Read", inputJSON: "")
            #expect(event.inputSummary == "")
        }
    }

    @Suite("Result summary")
    struct ResultSummary {
        @Test("Returns first 3 lines of output")
        func returnsFirstThreeLines() {
            let event = ToolUseEvent(id: "t", name: "Bash", resultOutput: "line1\nline2\nline3\nline4\nline5")
            #expect(event.resultSummary == "line1\nline2\nline3")
        }

        @Test("Truncates long lines to 120 characters")
        func truncatesLongOutput() {
            let longLine = String(repeating: "x", count: 200)
            let event = ToolUseEvent(id: "t", name: "Bash", resultOutput: longLine)
            #expect(event.resultSummary.count == 120)
            #expect(event.resultSummary.hasSuffix("..."))
        }

        @Test("Returns empty string for empty resultOutput")
        func returnsEmptyForEmptyResult() {
            let event = ToolUseEvent(id: "t", name: "Bash", resultOutput: "")
            #expect(event.resultSummary == "")
        }

        @Test("Short single line returned as-is")
        func shortSingleLineReturnedAsIs() {
            let event = ToolUseEvent(id: "t", name: "Read", resultOutput: "hello world")
            #expect(event.resultSummary == "hello world")
        }
    }

    @Test("Model configuration defaults")
    func modelConfigurationDefaults() {
        #expect(ModelConfiguration.default.cliAlias == "opus")
        #expect(ModelConfiguration.allModels.count == 3)
    }
}
