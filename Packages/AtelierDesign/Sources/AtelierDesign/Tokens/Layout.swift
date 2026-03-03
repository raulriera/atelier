import SwiftUI

/// Layout constraints for the reading column and window sizing.
///
/// Usage:
/// ```swift
/// .frame(maxWidth: Layout.readingWidth)
/// .frame(minWidth: Layout.minimumWindowWidth, minHeight: Layout.minimumWindowHeight)
/// ```
public enum Layout {
    /// 720pt — maximum width for timeline content and compose field.
    public static let readingWidth: CGFloat = 720
    /// 420pt — narrowest usable window width.
    public static let minimumWindowWidth: CGFloat = 420
    /// 480pt — shortest usable window height.
    public static let minimumWindowHeight: CGFloat = 480
}
