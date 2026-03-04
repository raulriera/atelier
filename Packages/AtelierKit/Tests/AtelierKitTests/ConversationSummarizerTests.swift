import Foundation
import Testing
@testable import AtelierKit

@Suite("ConversationSummarizer")
struct ConversationSummarizerTests {

    @Test func emptyItemsReturnsNil() {
        #expect(ConversationSummarizer.summarize([]) == nil)
    }

    @Test func userAndAssistantMessages() {
        let items = [
            TimelineItem(content: .userMessage(UserMessage(text: "Hello"))),
            TimelineItem(content: .assistantMessage(
                AssistantMessage(text: "Hi there!", isComplete: true)
            )),
        ]

        let summary = ConversationSummarizer.summarize(items)
        #expect(summary?.contains("User: Hello") == true)
        #expect(summary?.contains("Assistant: Hi there!") == true)
    }

    @Test func incompleteAssistantMessagesExcluded() {
        let items = [
            TimelineItem(content: .userMessage(UserMessage(text: "Hello"))),
            TimelineItem(content: .assistantMessage(
                AssistantMessage(text: "Still streaming...", isComplete: false)
            )),
        ]

        let summary = ConversationSummarizer.summarize(items)
        #expect(summary?.contains("User: Hello") == true)
        #expect(summary?.contains("streaming") != true)
    }

    @Test func longAssistantMessagesTruncated() {
        let longText = String(repeating: "a", count: 3000)
        let items = [
            TimelineItem(content: .assistantMessage(
                AssistantMessage(text: longText, isComplete: true)
            )),
        ]

        let summary = ConversationSummarizer.summarize(items)!
        // 2000 chars + "Assistant: " prefix + "..." suffix
        #expect(summary.count < 3000)
        #expect(summary.hasSuffix("..."))
    }

    @Test func completedToolSummaries() {
        var tool = ToolUseEvent(
            id: "t1",
            name: "Read",
            inputJSON: #"{"file_path":"/foo/bar.swift"}"#,
            status: .completed,
            resultOutput: "file content here"
        )
        tool.cacheInputProperties()

        let items = [
            TimelineItem(content: .toolUse(tool)),
        ]

        let summary = ConversationSummarizer.summarize(items)!
        #expect(summary.contains("Tool(Read File)"))
        #expect(summary.contains("/foo/bar.swift"))
    }

    @Test func runningToolsExcluded() {
        let tool = ToolUseEvent(id: "t1", name: "Bash", status: .running)
        let items = [
            TimelineItem(content: .toolUse(tool)),
        ]

        #expect(ConversationSummarizer.summarize(items) == nil)
    }

    @Test func systemEventsExcluded() {
        let items = [
            TimelineItem(content: .system(SystemEvent(kind: .sessionStarted, message: "Session started"))),
            TimelineItem(content: .userMessage(UserMessage(text: "Hi"))),
        ]

        let summary = ConversationSummarizer.summarize(items)!
        #expect(!summary.contains("session"))
        #expect(summary.contains("User: Hi"))
    }

    @Test func maxItemsTakesTail() {
        let items = (0..<10).map { i in
            TimelineItem(content: .userMessage(UserMessage(text: "msg-\(i)")))
        }

        let summary = ConversationSummarizer.summarize(items, maxItems: 3)!
        #expect(!summary.contains("msg-0"))
        #expect(!summary.contains("msg-6"))
        #expect(summary.contains("msg-7"))
        #expect(summary.contains("msg-8"))
        #expect(summary.contains("msg-9"))
    }
}
