import SwiftUI
import AtelierDesign
import AtelierKit

struct TimelineView: View {
    let session: Session
    var selectedToolID: String?
    var onSelectTool: ((ToolUseEvent) -> Void)?

    var body: some View {
        let items = session.items
        let tails = computeTails(for: items)

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(items.reversed().enumerated()), id: \.element.id) { reversedIndex, item in
                    let originalIndex = items.count - 1 - reversedIndex
                    let showsTail = tails[item.id] ?? true
                    let bottomPadding = spacingAfter(index: originalIndex, in: items)

                    TimelineItemView(
                        item: item,
                        session: session,
                        selectedToolID: selectedToolID,
                        onSelectTool: onSelectTool,
                        showsTail: showsTail
                    )
                    .padding(.bottom, bottomPadding)
                    .scaleEffect(x: 1, y: -1)
                }

                if items.isEmpty {
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

    // MARK: - Bubble Grouping

    /// Returns a dictionary mapping each item's ID to whether it should
    /// show the speech-bubble tail. Only the last message in a consecutive
    /// same-sender group shows the tail.
    private func computeTails(for items: [TimelineItem]) -> [UUID: Bool] {
        var result: [UUID: Bool] = [:]

        for (index, item) in items.enumerated() {
            guard let sender = item.content.groupableSender else {
                result[item.id] = true
                continue
            }

            let nextSender = items.indices.contains(index + 1)
                ? items[index + 1].content.groupableSender
                : nil

            // Show tail only if this is the last message from this sender
            result[item.id] = (nextSender != sender)
        }

        return result
    }

    /// Returns the bottom padding for the item at `index`.
    /// Tight spacing within a group, normal spacing between groups.
    private func spacingAfter(index: Int, in items: [TimelineItem]) -> CGFloat {
        guard items.indices.contains(index + 1) else { return 0 }

        let current = items[index].content.groupableSender
        let next = items[index + 1].content.groupableSender

        if let current, current == next {
            return Spacing.xxs  // 4pt — tight within group
        }
        return Spacing.sm  // 12pt — between groups
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
        case .system, .toolUse: nil
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
            if event.isFileOperation {
                FileCard(event: event, isSelected: event.id == selectedToolID, onSelect: onSelectTool)
            } else {
                ToolUseCell(event: event, isSelected: event.id == selectedToolID, onSelect: onSelectTool)
            }
        }
    }
}
