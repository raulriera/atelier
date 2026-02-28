import SwiftUI

/// Text-only button for secondary actions: Cancel, Dismiss, Skip.
///
/// Usage:
/// ```swift
/// Button("Cancel") { }.buttonStyle(.ghost)
/// ```
public struct GhostButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .foregroundStyle(.contentSecondary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .opacity(configuration.isPressed ? 0.6 : 1)
            .animation(Motion.settle, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GhostButtonStyle {
    /// Text-only button for secondary actions.
    public static var ghost: GhostButtonStyle { GhostButtonStyle() }
}
