import SwiftUI

/// iMessage-style bubble for assistant/received messages.
///
/// Dark gray background matching Messages.app received-message styling.
///
/// When `showsTail` is true (the default), the bottom-leading corner
/// uses a small radius to create the speech-bubble "tail" effect.
/// Consecutive grouped messages pass `showsTail: false` so only the
/// last bubble in the group shows the tail.
///
/// Usage:
/// ```swift
/// Text(response.text).plainContainer()
/// Text(grouped.text).plainContainer(showsTail: false)
/// ```
struct PlainContainerModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var showsTail: Bool = true

    private var bubbleShape: AnyShape {
        if showsTail {
            AnyShape(BubbleShape(tailEdge: .leading))
        } else {
            AnyShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    private var bubbleColor: Color {
        colorScheme == .dark ? Color(white: 0.22) : Color(white: 0.93)
    }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .foregroundStyle(.contentPrimary)
            .background(bubbleColor, in: bubbleShape)
    }
}

extension View {
    /// Applies assistant message bubble, optionally with tail on bottom-leading.
    public func plainContainer(showsTail: Bool = true) -> some View {
        modifier(PlainContainerModifier(showsTail: showsTail))
    }
}
