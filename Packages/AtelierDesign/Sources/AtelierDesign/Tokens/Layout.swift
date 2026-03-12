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
    /// 780pt — narrowest usable window width (conversation + inspector).
    public static let minimumWindowWidth: CGFloat = 780
    /// 1100pt — default window width when the inspector is open.
    public static let defaultWindowWidth: CGFloat = 1100
    /// 480pt — shortest usable window height.
    public static let minimumWindowHeight: CGFloat = 480
    /// 700pt — default window height.
    public static let defaultWindowHeight: CGFloat = 700
    /// 420pt — setup/folder picker panel width.
    public static let folderPickerWidth: CGFloat = 420
    /// 340pt — setup/folder picker panel height.
    public static let folderPickerHeight: CGFloat = 340
}
