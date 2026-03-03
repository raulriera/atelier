import SwiftUI

/// iMessage-style gradient bubble for user messages.
///
/// Asymmetric corners — large radius on three corners, small on
/// bottom-trailing to create the speech bubble "tail" effect.
///
/// Usage:
/// ```swift
/// Text(message.text).tintedContainer()
/// ```
struct TintedContainerModifier: ViewModifier {
    private let bubbleShape = UnevenRoundedRectangle(
        topLeadingRadius: 18,
        bottomLeadingRadius: 18,
        bottomTrailingRadius: 4,
        topTrailingRadius: 18,
        style: .continuous
    )

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    stops: [
                        .init(color: Color(red: 0.0, green: 0.48, blue: 1.0), location: 0),
                        .init(color: Color(red: 0.0, green: 0.36, blue: 0.88), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: bubbleShape
            )
    }
}

extension View {
    /// Applies user message surface with gradient.
    public func tintedContainer() -> some View {
        modifier(TintedContainerModifier())
    }
}
