import SwiftUI
import AtelierDesign
import AtelierKit

struct UserMessageCell: View {
    let message: UserMessage
    var isCancelled: Bool = false
    var showsTail: Bool = true

    /// Attachment-only messages render as free-floating thumbnails
    /// without a speech bubble, matching iMessage's photo layout.
    private var isAttachmentOnly: Bool {
        !message.attachments.isEmpty && message.text.isEmpty
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: Spacing.xxs) {
            if isAttachmentOnly {
                UserMessageAttachmentsView(attachments: message.attachments)
                    .opacity(isCancelled ? 0.5 : 1)
            } else {
                HStack {
                    Spacer(minLength: Spacing.xxl)
                    Text(message.text)
                        .font(.conversationBody)
                        .textSelection(.enabled)
                        .tintedContainer(showsTail: showsTail)
                        .opacity(isCancelled ? 0.5 : 1)
                }
            }

            if isCancelled {
                Text("Cancelled")
                    .font(.tokenCount)
                    .foregroundStyle(.contentTertiary)
                    .opacity(0.6)
                    .padding(.trailing, Spacing.xs)
            }
        }
    }
}
