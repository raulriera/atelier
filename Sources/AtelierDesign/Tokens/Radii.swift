import SwiftUI

/// Corner radii. Always pair with `.continuous` corner style.
///
/// Usage:
/// ```swift
/// .clipShape(.rect(cornerRadius: Radii.md, style: .continuous))
/// ```
public enum Radii {
    /// 6pt — small elements, badges.
    public static let sm: CGFloat = 6
    /// 10pt — cards, containers.
    public static let md: CGFloat = 10
    /// 16pt — large cards, panels.
    public static let lg: CGFloat = 16
}
