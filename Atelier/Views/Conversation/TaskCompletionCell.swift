import SwiftUI
import AtelierDesign
import AtelierKit

/// Timeline cell for a completed scheduled task. Tapping opens the inspector detail.
struct TaskCompletionCell: View {
    let event: TaskCompletionEvent

    var body: some View {
        Label(event.message, systemImage: event.result.health.iconName)
            .systemContainer()
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

#Preview("Healthy") {
    TaskCompletionCell(event: TaskCompletionEvent(
        name: "Daily standup summary",
        result: TaskRunResult(
            date: .now,
            succeeded: true,
            numTurns: 4,
            resultText: "Posted summary.",
            permissionDenials: [],
            durationMs: 12400,
            health: .healthy,
            userSummary: "completed successfully"
        )
    ))
    .padding()
}

#Preview("Warning") {
    TaskCompletionCell(event: TaskCompletionEvent(
        name: "Code review digest",
        result: TaskRunResult(
            date: .now,
            succeeded: true,
            numTurns: 8,
            resultText: "",
            permissionDenials: ["Bash"],
            durationMs: 45000,
            health: .warning,
            userSummary: "completed with warnings"
        )
    ))
    .padding()
}

#Preview("Failed") {
    TaskCompletionCell(event: TaskCompletionEvent(
        name: "Nightly backup check",
        result: TaskRunResult(
            date: .now,
            succeeded: false,
            numTurns: 1,
            resultText: "",
            permissionDenials: [],
            durationMs: 2100,
            health: .failed,
            userSummary: "failed to complete"
        )
    ))
    .padding()
}
