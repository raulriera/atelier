import SwiftUI

/// Plain button that does **not** dim its label when disabled.
///
/// Use for informational rows (tool cards, file cards) where `.disabled()` blocks
/// interaction for accessibility but the visual appearance should stay consistent.
///
/// Usage:
/// ```swift
/// Button { ... } label: { ... }
///     .buttonStyle(.plainUnfaded)
///     .disabled(!isTappable)
/// ```
public struct PlainUnfadedButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}

extension ButtonStyle where Self == PlainUnfadedButtonStyle {
    /// Plain button that ignores the disabled dimming effect.
    public static var plainUnfaded: PlainUnfadedButtonStyle { PlainUnfadedButtonStyle() }
}
