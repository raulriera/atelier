import SwiftUI

/// A 4-point spacing grid. Seven values cover every layout scenario.
///
/// Usage:
/// ```swift
/// .padding(Spacing.md)
/// VStack(spacing: Spacing.sm) { }
/// ```
public enum Spacing {
    /// 4pt — tight gaps (icon–label).
    public static let xxs: CGFloat = 4
    /// 8pt — related element spacing.
    public static let xs: CGFloat = 8
    /// 12pt — compact padding.
    public static let sm: CGFloat = 12
    /// 16pt — standard padding, card insets.
    public static let md: CGFloat = 16
    /// 24pt — section spacing.
    public static let lg: CGFloat = 24
    /// 32pt — major section breaks.
    public static let xl: CGFloat = 32
    /// 48pt — full-width breathing room.
    public static let xxl: CGFloat = 48
}
