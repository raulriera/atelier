import SwiftUI

/// Elevated surface for file cards, approval cards, and rich content.
///
/// Uses a thin material on dark backgrounds for subtle glass depth,
/// with a hairline border to define the edge.
///
/// Usage:
/// ```swift
/// VStack { diffView }.cardContainer()
/// ```
struct CardContainerModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(Spacing.md)
            .background {
                RoundedRectangle(cornerRadius: Radii.md, style: .continuous)
                    .fill(colorScheme == .dark ? AnyShapeStyle(.ultraThinMaterial) : AnyShapeStyle(.surfaceElevated))
            }
            .overlay(
                RoundedRectangle(cornerRadius: Radii.md, style: .continuous)
                    .strokeBorder(.white.opacity(colorScheme == .dark ? 0.08 : 0), lineWidth: 0.5)
            )
    }
}

extension View {
    /// Applies card surface — glass in dark mode, solid in light.
    public func cardContainer() -> some View {
        modifier(CardContainerModifier())
    }
}
