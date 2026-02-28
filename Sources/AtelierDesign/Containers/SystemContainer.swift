import SwiftUI

/// Styling for system and status messages.
///
/// Usage:
/// ```swift
/// Text("Session started").systemContainer()
/// ```
struct SystemContainerModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.metadata)
            .foregroundStyle(.contentSecondary)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
    }
}

extension View {
    /// Applies system message styling.
    public func systemContainer() -> some View {
        modifier(SystemContainerModifier())
    }
}
