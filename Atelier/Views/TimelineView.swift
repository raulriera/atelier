import SwiftUI
import AtelierDesign
import AtelierKit

struct TimelineView: View {
    let session: Session

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Spacing.md) {
                ForEach(session.items.reversed()) { item in
                    itemView(for: item)
                        .id(item.id)
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

    @ViewBuilder
    private func itemView(for item: TimelineItem) -> some View {
        switch item.content {
        case .userMessage(let msg):
            UserMessageCell(message: msg)
        case .assistantMessage(let msg):
            AssistantMessageCell(
                message: msg,
                streamingText: session.isStreaming && !msg.isComplete ? session.activeAssistantText : nil,
                isThinking: session.isStreaming && !msg.isComplete && session.isThinking
            )
        case .system(let event):
            SystemEventCell(event: event)
        }
    }
}
