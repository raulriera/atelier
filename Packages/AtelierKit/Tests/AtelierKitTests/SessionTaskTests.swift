import Testing
import Foundation
@testable import AtelierKit

@Suite("Session task state")
struct SessionTaskTests {

    @Test("taskEntries empty when no task events")
    @MainActor func taskEntriesEmptyWithNoTaskEvents() {
        let session = Session()
        session.appendUserMessage("Hello")
        session.beginAssistantMessage()
        session.applyDelta("Hi!")
        session.completeAssistantMessage(usage: TokenUsage())

        #expect(session.taskEntries.isEmpty)
    }

    @Test("taskEntries accumulates from non-consecutive task events")
    @MainActor func taskEntriesAccumulatesNonConsecutive() throws {
        let session = Session()
        session.beginAssistantMessage()

        // TaskCreate followed by a non-task tool, then TaskUpdate
        session.beginToolUse(id: "t1", name: "TaskCreate")
        session.applyToolInputDelta(id: "t1", json: #"{"subject":"Research topic"}"#)
        session.completeToolUse(id: "t1")

        session.beginToolUse(id: "t2", name: "Read")
        session.applyToolInputDelta(id: "t2", json: #"{"file_path":"notes.md"}"#)
        session.completeToolUse(id: "t2")

        session.beginToolUse(id: "t3", name: "TaskCreate")
        session.applyToolInputDelta(id: "t3", json: #"{"subject":"Write summary"}"#)
        session.completeToolUse(id: "t3")

        let entries = session.taskEntries
        #expect(entries.count == 2)
        #expect(entries[0].subject == "Research topic")
        #expect(entries[1].subject == "Write summary")
    }

    @Test("taskEntries reflects latest TodoWrite state")
    @MainActor func taskEntriesReflectsTodoWrite() throws {
        let session = Session()
        session.beginAssistantMessage()

        session.beginToolUse(id: "t1", name: "TodoWrite")
        session.applyToolInputDelta(id: "t1", json: #"{"todos":[{"id":"1","content":"First task","status":"pending"},{"id":"2","content":"Second task","status":"pending"}]}"#)
        session.completeToolUse(id: "t1")

        session.beginToolUse(id: "t2", name: "TodoWrite")
        session.applyToolInputDelta(id: "t2", json: #"{"todos":[{"id":"1","content":"First task","status":"completed"},{"id":"2","content":"Second task","status":"in_progress"}]}"#)
        session.completeToolUse(id: "t2")

        let entries = session.taskEntries
        #expect(entries.count == 2)
        #expect(entries[0].status == .completed)
        #expect(entries[1].status == .inProgress)
    }

    @Test("hasActiveTasks correct for mixed states")
    @MainActor func hasActiveTasksMixedStates() {
        let session = Session()
        session.beginAssistantMessage()

        // All completed
        session.beginToolUse(id: "t1", name: "TodoWrite")
        session.applyToolInputDelta(id: "t1", json: #"{"todos":[{"id":"1","content":"Done","status":"completed"}]}"#)
        session.completeToolUse(id: "t1")

        #expect(!session.hasActiveTasks)

        // Add one in-progress
        session.beginToolUse(id: "t2", name: "TodoWrite")
        session.applyToolInputDelta(id: "t2", json: #"{"todos":[{"id":"1","content":"Done","status":"completed"},{"id":"2","content":"Active","status":"in_progress"}]}"#)
        session.completeToolUse(id: "t2")

        #expect(session.hasActiveTasks)
    }

    @Test("hasActiveTasks false when no entries")
    @MainActor func hasActiveTasksFalseWhenEmpty() {
        let session = Session()
        #expect(!session.hasActiveTasks)
    }

    @Test("visibleTimelineItems excludes task events")
    @MainActor func visibleTimelineItemsExcludesTaskEvents() {
        let session = Session()
        session.beginAssistantMessage()

        session.beginToolUse(id: "t1", name: "Read")
        session.completeToolUse(id: "t1")

        session.beginToolUse(id: "t2", name: "TaskCreate")
        session.applyToolInputDelta(id: "t2", json: #"{"subject":"Do something"}"#)
        session.completeToolUse(id: "t2")

        session.beginToolUse(id: "t3", name: "TodoWrite")
        session.applyToolInputDelta(id: "t3", json: #"{"todos":[{"id":"1","content":"Task","status":"pending"}]}"#)
        session.completeToolUse(id: "t3")

        session.beginToolUse(id: "t4", name: "Bash")
        session.completeToolUse(id: "t4")

        // 4 tool items total, but visibleTimelineItems should exclude TaskCreate and TodoWrite
        let visible = session.visibleTimelineItems
        #expect(visible.count == 2)
        for item in visible {
            if case .toolUse(let event) = item.content {
                #expect(!event.isTaskOperation, "Task event \(event.name) should be excluded")
            }
        }
    }

    @Test("visibleTimelineItems excludes EnterPlanMode")
    @MainActor func visibleTimelineItemsExcludesEnterPlanMode() {
        let session = Session()
        session.beginAssistantMessage()

        session.beginToolUse(id: "t1", name: "EnterPlanMode")
        session.completeToolUse(id: "t1")

        session.beginToolUse(id: "t2", name: "ExitPlanMode")
        session.completeToolUse(id: "t2")

        session.beginToolUse(id: "t3", name: "Read")
        session.completeToolUse(id: "t3")

        let visible = session.visibleTimelineItems
        let toolNames = visible.compactMap {
            if case .toolUse(let e) = $0.content { return e.name }
            return nil
        }
        #expect(!toolNames.contains("EnterPlanMode"))
        #expect(toolNames.contains("ExitPlanMode"))
        #expect(toolNames.contains("Read"))
    }

    @Test("reset clears task state")
    @MainActor func resetClearsTaskState() {
        let session = Session()
        session.beginAssistantMessage()

        session.beginToolUse(id: "t1", name: "TaskCreate")
        session.applyToolInputDelta(id: "t1", json: #"{"subject":"Something"}"#)
        session.completeToolUse(id: "t1")

        #expect(!session.taskEntries.isEmpty)

        session.reset()

        #expect(session.taskEntries.isEmpty)
        #expect(!session.hasActiveTasks)
    }
}
