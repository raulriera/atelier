import SwiftUI

/// Subtle pulsing indicator shown when Claude is reasoning before responding.
public struct ThinkingIndicator: View {
    @State private var pulsing = false

    public init() {}

    public var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "brain")
                .font(.conversationBody)
            Text("Thinking\u{2026}")
                .font(.conversationBody)
        }
        .foregroundStyle(.contentSecondary)
        .opacity(pulsing ? 0.4 : 1.0)
        .animation(
            .easeInOut(duration: 1.0).repeatForever(autoreverses: true),
            value: pulsing
        )
        .onAppear {
            pulsing = true
        }
    }
}
