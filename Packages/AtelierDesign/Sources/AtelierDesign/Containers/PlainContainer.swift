import SwiftUI

/// Surface for assistant messages.
///
/// Usage:
/// ```swift
/// Text(response.text).plainContainer()
/// ```
struct PlainContainerModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Spacing.md)
    }
}

extension View {
    /// Applies assistant message padding.
    public func plainContainer() -> some View {
        modifier(PlainContainerModifier())
    }
}
