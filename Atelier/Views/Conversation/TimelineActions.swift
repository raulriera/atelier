import SwiftUI
import AtelierKit

/// Coordinator that holds timeline action handlers, injected via `@Environment`
/// so that `TimelineItemView` and individual cells don't need closure parameters.
///
/// By replacing per-view closure parameters with a single environment object,
/// `TimelineItemView` becomes a pure data struct that SwiftUI can diff efficiently —
/// closures are opaque to the diffing engine and would otherwise force every cell
/// to be treated as "new" on each parent re-render.
@MainActor
final class TimelineActions {
    /// Called when the user taps a completed tool card to inspect its output.
    var onSelectTool: ((ToolUseEvent) -> Void)?
    /// Called when the user taps a task completion cell to inspect its result.
    var onSelectTaskCompletion: ((TaskCompletionEvent) -> Void)?
    /// Called when the user approves or denies a tool approval request.
    var onApprovalDecision: ((String, String, ApprovalDecision) -> Void)?
    /// Called when the user selects an option in an ask-user question.
    var onAskUserResponse: ((String, Int, String?) -> Void)?
    /// Called when the user approves a plan review.
    var onPlanApprove: (() -> Void)?
    /// Called when the user enables a suggested capability.
    var onEnableCapability: ((String) -> Void)?
}

extension EnvironmentValues {
    @Entry var timelineActions: TimelineActions = TimelineActions()
}

#Preview {
    Text("TimelineActions environment test")
        .environment(\.timelineActions, TimelineActions())
}
