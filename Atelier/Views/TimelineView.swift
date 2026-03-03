import SwiftUI
import AtelierDesign
import AtelierKit

struct TimelineView: View {
    let session: Session
    var selectedToolID: String?
    var onSelectTool: ((ToolUseEvent) -> Void)?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.sm) {
                ForEach(session.items.reversed()) { item in
                    TimelineItemView(
                        item: item,
                        session: session,
                        selectedToolID: selectedToolID,
                        onSelectTool: onSelectTool
                    )
                    .scaleEffect(x: 1, y: -1)
                }

                if session.items.isEmpty {
                    WelcomeMessage()
                        .scaleEffect(x: 1, y: -1)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.md)
        }
        .scaleEffect(x: 1, y: -1)
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

    var body: some View {
        switch item.content {
        case .userMessage(let msg):
            UserMessageCell(message: msg)
        case .assistantMessage(let msg):
            if msg.isComplete {
                AssistantMessageCell(message: msg, streamingText: nil)
            } else {
                AssistantMessageCell(
                    message: msg,
                    streamingText: session.isStreaming ? session.activeAssistantText : nil,
                    isThinking: session.isStreaming && session.isThinking
                )
            }
        case .system(let event):
            SystemEventCell(event: event)
        case .toolUse(let event):
            if event.isFileOperation {
                FileCard(event: event, isSelected: event.id == selectedToolID, onSelect: onSelectTool)
            } else {
                ToolUseCell(event: event, isSelected: event.id == selectedToolID, onSelect: onSelectTool)
            }
        }
    }
}
