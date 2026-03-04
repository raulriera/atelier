import AtelierKit

/// Shared preview/debug fixtures for task states.
///
/// Used by TaskCard previews, TaskListOverlay previews, and the debug
/// toolbar button. Single source of truth for the JSON progression.
enum TaskPreviewFixtures {
    static let todoSteps: [(id: String, json: String)] = [
        ("todo-t1", #"{"todos":[{"id":"1","content":"Research competitive landscape","status":"pending"},{"id":"2","content":"Draft executive summary","status":"pending"},{"id":"3","content":"Review final deliverables","status":"pending"}]}"#),
        ("todo-t2", #"{"todos":[{"id":"1","content":"Research competitive landscape","status":"in_progress"},{"id":"2","content":"Draft executive summary","status":"pending"},{"id":"3","content":"Review final deliverables","status":"pending"}]}"#),
        ("todo-t3", #"{"todos":[{"id":"1","content":"Research competitive landscape","status":"completed"},{"id":"2","content":"Draft executive summary","status":"in_progress"},{"id":"3","content":"Review final deliverables","status":"pending"}]}"#),
        ("todo-t4", #"{"todos":[{"id":"1","content":"Research competitive landscape","status":"completed"},{"id":"2","content":"Draft executive summary","status":"completed"},{"id":"3","content":"Review final deliverables","status":"completed"}]}"#),
    ]

    /// Builds task entries by replaying the first N steps as TodoWrite events.
    static func entries(step: Int) -> [TaskEntry] {
        let events = todoSteps.prefix(step).map { step in
            ToolUseEvent(id: step.id, name: "TodoWrite", inputJSON: step.json, status: .completed)
        }
        return TaskEntry.buildList(from: events)
    }

    /// Injects TodoWrite events into a session up to the given step.
    @MainActor
    static func populateSession(_ session: Session, step: Int) {
        for s in todoSteps.prefix(step) {
            session.beginToolUse(id: s.id, name: "TodoWrite")
            session.applyToolInputDelta(id: s.id, json: s.json)
            session.completeToolUse(id: s.id)
        }
    }
}
