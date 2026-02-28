import SwiftUI

/// Compact button for use inside cards: View Diff, Expand, Copy.
///
/// Smaller than ghost, designed to sit alongside card content
/// without competing for attention.
///
/// Usage:
/// ```swift
/// Button("View Diff") { }.buttonStyle(.inline)
/// ```
public struct InlineButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .foregroundStyle(.contentAccent)
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xxs)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(Motion.settle, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == InlineButtonStyle {
    /// Compact button for use inside cards.
    public static var inline: InlineButtonStyle { InlineButtonStyle() }
}
