import SwiftUI

/// iMessage-style gradient bubble for user messages.
///
/// Uses the macOS system accent color so the bubble adapts when the
/// user changes their accent in System Settings, just like Messages.app.
///
/// When `showsTail` is true (the default), the bottom-trailing corner
/// uses a small radius to create the speech-bubble "tail" effect.
/// Consecutive grouped messages pass `showsTail: false` so only the
/// last bubble in the group shows the tail.
///
/// Usage:
/// ```swift
/// Text(message.text).tintedContainer()
/// Text(grouped.text).tintedContainer(showsTail: false)
/// ```
struct TintedContainerModifier: ViewModifier {
    var showsTail: Bool = true

    private var bubbleShape: AnyShape {
        if showsTail {
            AnyShape(BubbleShape(tailEdge: .trailing))
        } else {
            AnyShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .foregroundStyle(.white)
            .background(Color.accentColor, in: bubbleShape)
    }
}

extension View {
    /// Applies user message surface with accent-color gradient.
    public func tintedContainer(showsTail: Bool = true) -> some View {
        modifier(TintedContainerModifier(showsTail: showsTail))
    }
}
