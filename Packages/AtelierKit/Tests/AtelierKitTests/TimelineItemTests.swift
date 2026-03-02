import Testing
import Foundation
@testable import AtelierKit

@Test func userMessageRoundTrip() throws {
    let item = TimelineItem(content: .userMessage(UserMessage(text: "Hello")))
    let data = try JSONEncoder().encode(item)
    let decoded = try JSONDecoder().decode(TimelineItem.self, from: data)
    #expect(decoded.id == item.id)
    if case .userMessage(let msg) = decoded.content {
        #expect(msg.text == "Hello")
    } else {
        Issue.record("Expected userMessage")
    }
}

@Test func assistantMessageRoundTrip() throws {
    let usage = TokenUsage(inputTokens: 10, outputTokens: 25)
    let assistant = AssistantMessage(text: "Hi there", isComplete: true, usage: usage)
    let item = TimelineItem(content: .assistantMessage(assistant))
    let data = try JSONEncoder().encode(item)
    let decoded = try JSONDecoder().decode(TimelineItem.self, from: data)
    if case .assistantMessage(let msg) = decoded.content {
        #expect(msg.text == "Hi there")
        #expect(msg.isComplete)
        #expect(msg.usage.inputTokens == 10)
        #expect(msg.usage.outputTokens == 25)
    } else {
        Issue.record("Expected assistantMessage")
    }
}

@Test func systemEventRoundTrip() throws {
    let event = SystemEvent(kind: .error, message: "Something went wrong")
    let item = TimelineItem(content: .system(event))
    let data = try JSONEncoder().encode(item)
    let decoded = try JSONDecoder().decode(TimelineItem.self, from: data)
    if case .system(let evt) = decoded.content {
        #expect(evt.kind == .error)
        #expect(evt.message == "Something went wrong")
    } else {
        Issue.record("Expected system event")
    }
}

@Test func stableIdentity() throws {
    let id = UUID()
    let item = TimelineItem(id: id, content: .userMessage(UserMessage(text: "test")))
    let data = try JSONEncoder().encode(item)
    let decoded = try JSONDecoder().decode(TimelineItem.self, from: data)
    #expect(decoded.id == id)
}

@Test func modelConfigurationDefaults() {
    #expect(ModelConfiguration.default.cliAlias == "opus")
    #expect(ModelConfiguration.allModels.count == 3)
}

// MARK: - ToolUseEvent

@Test func toolUseEventRoundTrip() throws {
    let event = ToolUseEvent(id: "toolu_abc", name: "Read", inputJSON: "{\"file_path\":\"test.swift\"}", status: .completed)
    let item = TimelineItem(content: .toolUse(event))
    let data = try JSONEncoder().encode(item)
    let decoded = try JSONDecoder().decode(TimelineItem.self, from: data)
    if case .toolUse(let evt) = decoded.content {
        #expect(evt.id == "toolu_abc")
        #expect(evt.name == "Read")
        #expect(evt.inputJSON == "{\"file_path\":\"test.swift\"}")
        #expect(evt.status == .completed)
    } else {
        Issue.record("Expected toolUse")
    }
}

@Test func inputSummaryExtractsFilePath() {
    let event = ToolUseEvent(id: "t1", name: "Read", inputJSON: "{\"file_path\":\"/src/main.swift\"}")
    #expect(event.inputSummary == "/src/main.swift")
}

@Test func inputSummaryExtractsCommand() {
    let event = ToolUseEvent(id: "t2", name: "Bash", inputJSON: "{\"command\":\"ls -la\"}")
    #expect(event.inputSummary == "ls -la")
}

@Test func inputSummaryExtractsPattern() {
    let event = ToolUseEvent(id: "t3", name: "Glob", inputJSON: "{\"pattern\":\"**/*.swift\"}")
    #expect(event.inputSummary == "**/*.swift")
}

@Test func inputSummaryTruncatesLongValues() {
    let longPath = String(repeating: "a", count: 100)
    let event = ToolUseEvent(id: "t4", name: "Read", inputJSON: "{\"file_path\":\"\(longPath)\"}")
    #expect(event.inputSummary.count == 80)
    #expect(event.inputSummary.hasSuffix("..."))
}

@Test func inputSummaryReturnsEmptyForInvalidJSON() {
    let event = ToolUseEvent(id: "t5", name: "Read", inputJSON: "not json")
    #expect(event.inputSummary == "")
}

@Test func inputSummaryReturnsEmptyForEmptyJSON() {
    let event = ToolUseEvent(id: "t6", name: "Read", inputJSON: "")
    #expect(event.inputSummary == "")
}
