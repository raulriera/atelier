import SwiftUI

/// Muted icon + text for metadata display: token counts, timestamps, file sizes.
///
/// Usage:
/// ```swift
/// Label("847 tokens", systemImage: "number").labelStyle(.caption)
/// ```
public struct CaptionLabelStyle: LabelStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Spacing.xxs) {
            configuration.icon
            configuration.title
        }
        .font(.metadata)
        .foregroundStyle(.contentSecondary)
    }
}

extension LabelStyle where Self == CaptionLabelStyle {
    /// Muted icon + text for metadata.
    public static var caption: CaptionLabelStyle { CaptionLabelStyle() }
}
