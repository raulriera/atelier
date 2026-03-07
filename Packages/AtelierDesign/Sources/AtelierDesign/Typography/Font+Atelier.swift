import SwiftUI

extension Font {
    /// Message text in the conversation timeline.
    public static let conversationBody: Font = .title3

    /// Inline code spans and code blocks.
    public static let conversationCode: Font = .title3.monospaced()

    /// Card headings, file names.
    public static let cardTitle: Font = .title3

    /// Card descriptions, secondary card content.
    /// Matches conversation body so cards feel part of the same flow.
    public static let cardBody: Font = .title3

    /// Section labels in the conversation.
    public static let sectionTitle: Font = .title3

    /// Token counts, cost display — monospaced digits for alignment.
    public static let tokenCount: Font = .callout.monospacedDigit()

    /// Timestamps, secondary metadata, captions.
    public static let metadata: Font = .body
}
