import SwiftUI
import AtelierDesign
import AtelierKit

struct TimelineView: View {
    let session: Session

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: Spacing.md) {
                    WelcomeMessage()

                    ForEach(session.items) { item in
                        itemView(for: item)
                            .id(item.id)
                            .transition(Motion.timelineInsert)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.md)
            }
            .onChange(of: session.items.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: session.activeAssistantText) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    @ViewBuilder
    private func itemView(for item: TimelineItem) -> some View {
        switch item.content {
        case .userMessage(let msg):
            UserMessageCell(message: msg)
        case .assistantMessage(let msg):
            AssistantMessageCell(
                message: msg,
                streamingText: session.isStreaming && !msg.isComplete ? session.activeAssistantText : nil
            )
        case .system(let event):
            SystemEventCell(event: event)
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastID = session.items.last?.id else { return }
        withAnimation(Motion.settle) {
            proxy.scrollTo(lastID, anchor: .bottom)
        }
    }
}
