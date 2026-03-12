import Foundation
import Testing
@testable import AtelierKit

@Suite("TaskEntry")
struct TaskEntryTests {

    // MARK: - TodoWrite parsing

    /// Reproduces the real CLI payload which omits `id` from todo items.
    /// Regression test: TodoItem previously required `id`, causing every
    /// item to be silently dropped and the task list to appear empty.
    @Test("Builds entries from TodoWrite without id fields")
    func todoWriteWithoutIds() throws {
        let event = makeTodoWriteEvent(inputJSON: """
        {"todos":[
            {"content":"Create shared layout","status":"pending"},
            {"content":"Update all pages","status":"in_progress"},
            {"content":"Clean up CSS","status":"completed"}
        ]}
        """)

        let entries = TaskEntry.buildList(from: [event])

        #expect(entries.count == 3)
        let first = try #require(entries.first)
        #expect(first.subject == "Create shared layout")
        #expect(first.status == .pending)
        #expect(entries[1].status == .inProgress)
        #expect(entries[2].status == .completed)
    }

    @Test("Builds entries from TodoWrite with id fields")
    func todoWriteWithIds() throws {
        let event = makeTodoWriteEvent(inputJSON: """
        {"todos":[
            {"id":"abc","content":"Task A","status":"pending"},
            {"id":"def","content":"Task B","status":"completed"}
        ]}
        """)

        let entries = TaskEntry.buildList(from: [event])

        #expect(entries.count == 2)
        let first = try #require(entries.first)
        #expect(first.id == "abc")
        #expect(first.subject == "Task A")
    }

    @Test("Uses last TodoWrite when multiple exist")
    func lastTodoWriteWins() {
        let first = makeTodoWriteEvent(inputJSON: """
        {"todos":[{"content":"Old task","status":"pending"}]}
        """)
        let second = makeTodoWriteEvent(inputJSON: """
        {"todos":[{"content":"New task","status":"in_progress"}]}
        """)

        let entries = TaskEntry.buildList(from: [first, second])

        #expect(entries.count == 1)
        #expect(entries.first?.subject == "New task")
        #expect(entries.first?.status == .inProgress)
    }

    @Test("Filters out deleted items")
    func deletedItemsFiltered() {
        let event = makeTodoWriteEvent(inputJSON: """
        {"todos":[
            {"content":"Keep me","status":"pending"},
            {"content":"Delete me","status":"deleted"}
        ]}
        """)

        let entries = TaskEntry.buildList(from: [event])

        #expect(entries.count == 1)
        #expect(entries.first?.subject == "Keep me")
    }

    @Test("Items missing content are skipped")
    func missingContentSkipped() {
        let event = makeTodoWriteEvent(inputJSON: """
        {"todos":[
            {"status":"pending"},
            {"content":"Valid","status":"pending"}
        ]}
        """)

        let entries = TaskEntry.buildList(from: [event])

        #expect(entries.count == 1)
        #expect(entries.first?.subject == "Valid")
    }

    // MARK: - Helpers

    private func makeTodoWriteEvent(inputJSON: String) -> ToolUseEvent {
        ToolUseEvent(id: UUID().uuidString, name: "TodoWrite", inputJSON: inputJSON, status: .completed)
    }
}
