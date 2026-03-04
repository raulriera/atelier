import SwiftUI
import AtelierDesign
import AtelierKit

struct AssistantMessageCell: View {
    let message: AssistantMessage
    let streamingText: String?
    let isThinking: Bool
    var showsTail: Bool = true

    init(message: AssistantMessage, streamingText: String?, isThinking: Bool = false, showsTail: Bool = true) {
        self.message = message
        self.streamingText = streamingText
        self.isThinking = isThinking
        self.showsTail = showsTail
    }

    var displayText: String {
        if let streaming = streamingText, !streaming.isEmpty {
            return streaming
        }
        return message.text
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack {
                Group {
                    if displayText.isEmpty {
                        if message.isComplete {
                            // Stopped before any text arrived — show nothing
                            EmptyView()
                        } else if isThinking {
                            ThinkingIndicator()
                        } else {
                            StreamingIndicator()
                        }
                    } else {
                        MarkdownContent(source: displayText)
                    }
                }
                .plainContainer(showsTail: showsTail)

                Spacer(minLength: Spacing.xxl)
            }

            if message.isComplete, message.usage.outputTokens > 0 {
                Text("\(message.usage.inputTokens + message.usage.outputTokens) tokens")
                    .font(.tokenCount)
                    .foregroundStyle(.contentTertiary)
                    .opacity(0.6)
                    .padding(.leading, Spacing.xs)
            }
        }
    }
}
