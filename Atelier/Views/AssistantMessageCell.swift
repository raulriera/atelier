import SwiftUI
import AtelierDesign
import AtelierKit

struct AssistantMessageCell: View {
    let message: AssistantMessage
    let streamingText: String?

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
                        StreamingIndicator()
                    } else {
                        Text(displayText)
                            .font(.conversationBody)
                            .textSelection(.enabled)
                    }
                }
                .plainContainer()

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
