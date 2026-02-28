import SwiftUI

/// Surface for user messages.
///
/// Usage:
/// ```swift
/// Text(message.text).tintedContainer()
/// ```
struct TintedContainerModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Spacing.md)
            .background(.surfaceTinted, in: .rect(cornerRadius: Radii.md, style: .continuous))
    }
}

extension View {
    /// Applies user message surface.
    public func tintedContainer() -> some View {
        modifier(TintedContainerModifier())
    }
}
