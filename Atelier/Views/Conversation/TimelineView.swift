import SwiftUI
import AtelierDesign
import AtelierKit

struct TimelineView: View {
    let session: Session
    let capabilityStore: CapabilityStore
    @Binding var draft: String
    var selectedToolID: String?
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
                if session.hasOlderItems {
                    Color.clear
                        .frame(height: 1)
                        .onAppear { session.loadOlderItems() }
                }

                if items.isEmpty && !session.hasOlderItems {
                    WelcomeView(draft: $draft, enabledCapabilityIDs: capabilityStore.enabledIDs)
                }

                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    let currentSender = item.content.groupableSender
                    let nextSender = items.indices.contains(index + 1) ? items[index + 1].content.groupableSender : nil
                    let showsTail = currentSender == nil || nextSender != currentSender
                    let bottomPadding: CGFloat = if let currentSender, currentSender == nextSender { Spacing.xxs } else { index < items.count - 1 ? Spacing.sm : 0 }

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
                        onEnableCapability: onEnableCapability,
                        showsTail: showsTail
                    )
                    .padding(.bottom, bottomPadding)
                }
            }
            .frame(maxWidth: Layout.readingWidth)
            .padding(.horizontal, Spacing.md)
            .frame(maxWidth: .infinity)
            .padding(.bottom, Spacing.md)
        }
    }
}

// MARK: - Groupable Sender

private extension TimelineContent {
    var groupableSender: String? {
        switch self {
        case .userMessage: "user"
        case .assistantMessage: "assistant"
        case .system, .toolUse, .approval, .askUser, .taskCompletion: nil
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
    var showsTail: Bool = true

    var body: some View {
        switch item.content {
        case .userMessage(let msg):
            UserMessageCell(message: msg, isCancelled: session.cancelledItemIDs.contains(item.id), showsTail: showsTail)
        case .assistantMessage(let msg):
            if msg.isComplete {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    AssistantMessageCell(message: msg, streamingText: nil, showsTail: showsTail)

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
                    isThinking: session.isStreaming && session.isThinking,
                    showsTail: showsTail
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
