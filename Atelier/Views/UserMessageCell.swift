import SwiftUI
import AtelierDesign
import AtelierKit

struct UserMessageCell: View {
    let message: UserMessage
    var isCancelled: Bool = false

    var body: some View {
        HStack {
            Spacer(minLength: Spacing.xxl)
            Text(message.text)
                .font(.conversationBody)
                .textSelection(.enabled)
                .tintedContainer()
                .opacity(isCancelled ? 0.5 : 1)
        }
    }
}
