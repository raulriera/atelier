import SwiftUI

/// Filled accent button for primary actions: Send, Approve, Confirm.
///
/// Compresses slightly on press for tactile feedback (Principle 5).
///
/// Usage:
/// ```swift
/// Button("Send") { }.buttonStyle(.primary)
/// ```
public struct PrimaryButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(.contentAccent, in: .capsule)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Motion.settle, value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    /// Filled accent button for primary actions.
    public static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}
