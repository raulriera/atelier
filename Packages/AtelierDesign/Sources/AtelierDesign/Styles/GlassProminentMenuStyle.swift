import SwiftUI

/// Menu styled as a prominent Liquid Glass button.
///
/// Use when a `Menu` needs the same accent-tinted glass appearance as
/// `.buttonStyle(.glassProminent)`. The built-in `.menuStyle(.button)`
/// renders a plain button that ignores the button-style environment,
/// so this custom style bridges the gap by applying a tinted glass effect
/// over the button menu style.
///
/// Usage:
/// ```swift
/// Menu { … } label: { Text("Approve") } primaryAction: { … }
///     .menuStyle(.glassProminent)
/// ```
public struct GlassProminentMenuStyle: MenuStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        Menu(configuration)
            .menuStyle(.button)
            .glassEffect(.regular.tint(.accentColor).interactive(), in: .rect(cornerRadius: Radii.sm))
    }
}

extension MenuStyle where Self == GlassProminentMenuStyle {
    /// A menu style that renders as a prominent Liquid Glass button.
    public static var glassProminent: GlassProminentMenuStyle { GlassProminentMenuStyle() }
}
