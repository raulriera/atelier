import Foundation

/// A renderable block parsed from markdown source.
public enum MarkdownBlock: Sendable, Equatable {
    case paragraph(AttributedString)
    case heading(level: Int, AttributedString)
    case codeBlock(language: String?, code: String)
    case list(ordered: Bool, items: [AttributedString])
    case blockQuote(AttributedString)
    case table(headers: [AttributedString], rows: [[AttributedString]])
    case thematicBreak
}
