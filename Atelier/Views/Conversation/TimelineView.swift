import SwiftUI
import AtelierDesign
import AtelierKit

struct TimelineView: View {
    let session: Session
    let capabilityStore: CapabilityStore
    let isLoaded: Bool
    @Binding var draft: String
    var selectedToolID: String?
    @Environment(\.inspectorInset) private var inspectorInset
    var onSelectTool: ((ToolUseEvent) -> Void)?
    var onSelectTaskCompletion: ((TaskCompletionEvent) -> Void)?
    var onApprovalDecision: ((String, String, ApprovalDecision) -> Void)?
    var onAskUserResponse: ((String, Int, String?) -> Void)?
    var onPlanApprove: (() -> Void)?
    var onEnableCapability: ((String) -> Void)?

    var body: some View {
        let items = session.visibleTimelineItems

        ChatScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if isLoaded && items.isEmpty {
                    WelcomeView(draft: $draft, enabledCapabilityIDs: capabilityStore.enabledIDs)
                }

                ForEach(items) { item in
                    TimelineItemView(
                        item: item,
                        session: session,
                        capabilityStore: capabilityStore,
                        selectedToolID: selectedToolID,
                        onSelectTool: onSelectTool,
                        onSelectTaskCompletion: onSelectTaskCompletion,
                        onApprovalDecision: onApprovalDecision,
                        onAskUserResponse: onAskUserResponse,
                        onPlanApprove: onPlanApprove,
                        onEnableCapability: onEnableCapability
                    )
                    .padding(.bottom, Spacing.sm)
                }
            }
            .frame(maxWidth: Layout.readingWidth)
            .padding(.horizontal, Spacing.md)
            .frame(maxWidth: .infinity)
            .padding(.bottom, Spacing.md)
            .offset(x: -inspectorInset)
        }
    }

}

/// Separate view per timeline item so @Observable tracking is scoped:
/// only the incomplete assistant message tracks streaming properties.
/// Completed messages, user messages, system events, and tool cards
/// never re-evaluate when streaming text changes.
private struct TimelineItemView: View {
    let item: TimelineItem
    let session: Session
    let capabilityStore: CapabilityStore
    let selectedToolID: String?
    let onSelectTool: ((ToolUseEvent) -> Void)?
    let onSelectTaskCompletion: ((TaskCompletionEvent) -> Void)?
    var onApprovalDecision: ((String, String, ApprovalDecision) -> Void)?
    var onAskUserResponse: ((String, Int, String?) -> Void)?
    var onPlanApprove: (() -> Void)?
    var onEnableCapability: ((String) -> Void)?

    var body: some View {
        switch item.content {
        case .userMessage(let msg):
            UserMessageCell(message: msg, isCancelled: session.cancelledItemIDs.contains(item.id))
        case .assistantMessage(let msg):
            if msg.isComplete {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    AssistantMessageCell(message: msg, streamingText: nil)

                    let suggested = capabilityStore.disabledCapabilities(mentionedIn: msg.text)
                    if !suggested.isEmpty {
                        CapabilitySuggestionBar(capabilities: suggested, onEnable: onEnableCapability)
                            .transition(Motion.approvalAppear)
                    }
                }
            } else {
                AssistantMessageCell(
                    message: msg,
                    streamingText: session.isStreaming ? session.activeAssistantText : nil,
                    isThinking: session.isStreaming && session.isThinking
                )
            }
        case .system(let event):
            SystemEventCell(event: event)
        case .taskCompletion(let event):
            Button { onSelectTaskCompletion?(event) } label: {
                TaskCompletionCell(event: event)
            }
            .buttonStyle(.plain)
        case .toolUse(let event):
            if event.isPlanReview {
                PlanReviewCard(
                    event: event,
                    planFilePath: session.planFilePath(for: event.id),
                    resolution: session.planResolution(for: event.id),
                    onApprove: onPlanApprove
                )
            } else if event.isFileOperation {
                FileCard(event: event, isSelected: event.id == selectedToolID, onSelect: onSelectTool)
            } else {
                ToolUseCell(event: event, isSelected: event.id == selectedToolID, onSelect: onSelectTool)
            }
        case .approval(let event):
            ApprovalCard(event: event, onDecision: onApprovalDecision)
        case .askUser(let event):
            AskUserCard(event: event, onResponse: onAskUserResponse)
        }
    }
}
