import SwiftUI

/// Glass material background with rainbow border and outer glow on focus.
///
/// Shared visual treatment for text input fields. Applies:
/// - Ultra-thin material background with rounded corners
/// - `AIGlow.angular` stroke border when focused and window appears active
/// - Soft outer glow halo when focused and window appears active
/// - `Motion.morph` animation on focus transitions
///
/// Usage:
/// ```swift
/// TextEditor(text: $text)
///     .glowingFieldContainer(isFocused: isFocused, cornerRadius: Radii.md)
/// ```
struct GlowingFieldContainer: ViewModifier {
    let isFocused: Bool
    let cornerRadius: CGFloat

    @Environment(\.appearsActive) private var appearsActive

    private var showsGlow: Bool {
        isFocused && appearsActive
    }

    func body(content: Content) -> some View {
        content
            .background(
                .ultraThinMaterial,
                in: .rect(cornerRadius: cornerRadius, style: .continuous)
            )
            .overlay {
                if showsGlow {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(AIGlow.angular, lineWidth: 1.5)
                        .opacity(0.6)
                        .transition(.opacity)
                }
            }
            .background {
                if showsGlow {
                    RoundedRectangle(cornerRadius: cornerRadius + 4, style: .continuous)
                        .fill(AIGlow.angular)
                        .blur(radius: 12)
                        .opacity(0.2)
                        .padding(-4)
                        .transition(.opacity)
                }
            }
            .animation(Motion.morph, value: showsGlow)
    }
}

extension View {
    /// Wraps the view in a glass material with rainbow border and glow on focus.
    public func glowingFieldContainer(isFocused: Bool, cornerRadius: CGFloat = Radii.md) -> some View {
        modifier(GlowingFieldContainer(isFocused: isFocused, cornerRadius: cornerRadius))
    }
}
