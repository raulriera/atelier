import SwiftUI
import AtelierDesign
import AtelierKit

struct UserMessageCell: View {
    let message: UserMessage
    var isCancelled: Bool = false
    var showsTail: Bool = true

    var body: some View {
        VStack(alignment: .trailing, spacing: Spacing.xxs) {
            HStack {
                Spacer(minLength: Spacing.xxl)
                Text(message.text)
                    .font(.conversationBody)
                    .textSelection(.enabled)
                    .tintedContainer(showsTail: showsTail)
                    .opacity(isCancelled ? 0.5 : 1)
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
