import SwiftUI

/// iMessage-style bubble for assistant/received messages.
///
/// Asymmetric corners — large radius on three corners, small on
/// bottom-leading to create the speech bubble "tail" effect.
/// Gray background matching received message styling.
///
/// Usage:
/// ```swift
/// Text(response.text).plainContainer()
/// ```
struct PlainContainerModifier: ViewModifier {
    private let bubbleShape = UnevenRoundedRectangle(
        topLeadingRadius: 18,
        bottomLeadingRadius: 4,
        bottomTrailingRadius: 18,
        topTrailingRadius: 18,
        style: .continuous
    )

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .foregroundStyle(.contentPrimary)
            .background(.surfaceElevated, in: bubbleShape)
    }
}

extension View {
    /// Applies assistant message bubble with tail on bottom-leading.
    public func plainContainer() -> some View {
        modifier(PlainContainerModifier())
    }
}
