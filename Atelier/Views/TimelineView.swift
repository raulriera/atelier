import SwiftUI
import AtelierDesign
import AtelierKit

struct TimelineView: View {
    let session: Session

    @State private var scrollPosition = ScrollPosition(edge: .bottom)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                WelcomeMessage()

                ForEach(session.items) { item in
                    itemView(for: item)
                        .id(item.id)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.md)
        }
        .scrollPosition($scrollPosition)
        .defaultScrollAnchor(.bottom)
        .onChange(of: session.items.count) { _, _ in
            withAnimation(Motion.settle) {
                scrollPosition.scrollTo(edge: .bottom)
            }
        }
        .onChange(of: session.activeAssistantText) { _, _ in
            withAnimation(Motion.settle) {
                scrollPosition.scrollTo(edge: .bottom)
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
}
