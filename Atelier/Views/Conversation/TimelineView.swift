import SwiftUI
import AtelierDesign
import AtelierKit

struct TimelineView: View {
    let session: Session
    var selectedToolID: String?
    var onSelectTool: ((ToolUseEvent) -> Void)?
    var onApprovalDecision: ((String, ApprovalDecision) -> Void)?
    var onAskUserResponse: ((String, Int, String?) -> Void)?
    var onPlanApprove: (() -> Void)?

    var body: some View {
        let items = session.visibleTimelineItems
        let hasPlanEvents = items.contains { if case .toolUse(let e) = $0.content { e.isPlanReview } else { false } }
        let resolvedPlanIDs = hasPlanEvents ? Self.resolvedPlanIDs(in: items, session: session) : []
        let planFilePaths = hasPlanEvents ? Self.planFilePaths(in: items, session: session) : [:]

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.reversed().enumerated()), id: \.element.id) { reversedIndex, item in
                    let originalIndex = items.count - 1 - reversedIndex
                    let currentSender = item.content.groupableSender
                    let nextSender = items.indices.contains(originalIndex + 1) ? items[originalIndex + 1].content.groupableSender : nil
                    let showsTail = currentSender == nil || nextSender != currentSender
                    let bottomPadding: CGFloat = if let currentSender, currentSender == nextSender { Spacing.xxs } else { originalIndex < items.count - 1 ? Spacing.sm : 0 }

                    TimelineItemView(
                        item: item,
                        session: session,
                        selectedToolID: selectedToolID,
                        onSelectTool: onSelectTool,
                        onApprovalDecision: onApprovalDecision,
                        onAskUserResponse: onAskUserResponse,
                        onPlanApprove: onPlanApprove,
                        resolvedPlanIDs: resolvedPlanIDs,
                        planFilePaths: planFilePaths,
                        showsTail: showsTail
                    )
                    .padding(.bottom, bottomPadding)
                    .scaleEffect(x: 1, y: -1)
                }

                // Auto-load earlier messages when scrolling to the top
                if session.hasOlderItems {
                    Color.clear
                        .frame(height: 1)
                        .onAppear { session.loadOlderItems() }
                }

                if items.isEmpty && !session.hasOlderItems {
                    WelcomeMessage()
                        .scaleEffect(x: 1, y: -1)
                }
            }
            .frame(maxWidth: Layout.readingWidth)
            .padding(.horizontal, Spacing.md)
            .frame(maxWidth: .infinity)
            .padding(.bottom, Spacing.md)
        }
        .scaleEffect(x: 1, y: -1)
    }

    /// Pre-computes plan file paths for each ExitPlanMode event.
    ///
    /// The CLI writes plans to `~/.claude/plans/*.md` before ExitPlanMode.
    /// Paths are resolved here (pure array scan, no I/O) so each
    /// `PlanReviewCard` can load its content asynchronously via `.task`.
    private static func planFilePaths(in items: [TimelineItem], session: Session) -> [String: String] {
        var paths: [String: String] = [:]
        for item in items {
            guard case .toolUse(let event) = item.content, event.isPlanReview else { continue }
            guard let path = session.planFilePath(before: event.id) else { continue }
            paths[event.id] = path
        }
        return paths
    }

    /// Pre-computes which ExitPlanMode events have been resolved.
    ///
    /// A plan is resolved when a user message follows it in the timeline,
    /// or when there are no pending ExitPlanMode approvals (user tapped Approve).
    /// Scanned once per render cycle to avoid recomputing inside each
    /// `TimelineItemView` body.
    private static func resolvedPlanIDs(in items: [TimelineItem], session: Session) -> Set<String> {
        let hasPendingPlanApproval = session.pendingApproval(toolName: "ExitPlanMode") != nil

        var resolved = Set<String>()
        var sawUserMessage = false
        for item in items.reversed() {
            if case .userMessage = item.content { sawUserMessage = true }
            else if case .toolUse(let event) = item.content, event.isPlanReview {
                if sawUserMessage || !hasPendingPlanApproval {
                    resolved.insert(event.id)
                }
            }
        }
        return resolved
    }
}

// MARK: - Groupable Sender

private extension TimelineContent {
    /// Returns a sender identifier for grouping purposes.
    /// Only user and assistant messages participate in groups;
    /// system events and tool-use cards always break groups.
    var groupableSender: String? {
        switch self {
        case .userMessage: "user"
        case .assistantMessage: "assistant"
        case .system, .toolUse, .approval, .askUser: nil
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
    let selectedToolID: String?
    let onSelectTool: ((ToolUseEvent) -> Void)?
    var onApprovalDecision: ((String, ApprovalDecision) -> Void)?
    var onAskUserResponse: ((String, Int, String?) -> Void)?
    var onPlanApprove: (() -> Void)?
    var resolvedPlanIDs: Set<String> = []
    var planFilePaths: [String: String] = [:]
    var showsTail: Bool = true

    var body: some View {
        switch item.content {
        case .userMessage(let msg):
            UserMessageCell(message: msg, isCancelled: session.cancelledItemIDs.contains(item.id), showsTail: showsTail)
        case .assistantMessage(let msg):
            if msg.isComplete {
                AssistantMessageCell(message: msg, streamingText: nil, showsTail: showsTail)
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
        case .toolUse(let event):
            if event.isPlanReview {
                PlanReviewCard(
                    event: event,
                    planFilePath: planFilePaths[event.id],
                    isResolved: resolvedPlanIDs.contains(event.id),
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
