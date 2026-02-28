import SwiftUI

extension Font {
    /// Message text in the conversation timeline.
    public static let conversationBody: Font = .body

    /// Inline code spans and code blocks.
    public static let conversationCode: Font = .body.monospaced()

    /// Card headings, file names.
    public static let cardTitle: Font = .headline

    /// Card descriptions, secondary card content.
    public static let cardBody: Font = .subheadline

    /// Section labels in the conversation.
    public static let sectionTitle: Font = .title3

    /// Token counts, cost display — monospaced digits for alignment.
    public static let tokenCount: Font = .caption2.monospacedDigit()

    /// Timestamps, secondary metadata.
    public static let metadata: Font = .caption
}
