import Foundation
import SwiftUI
import Markdown

/// Converts inline markup nodes to `AttributedString`.
public struct InlineText {
    public static func attributedString(from inlines: some Sequence<InlineMarkup>) -> AttributedString {
        var result = AttributedString()
        for inline in inlines {
            result.append(convert(inline))
        }
        return result
    }

    private static func convert(_ inline: any InlineMarkup) -> AttributedString {
        switch inline {
        case let text as Markdown.Text:
            return AttributedString(text.string)

        case let strong as Strong:
            var attr = attributedString(from: childInlines(of: strong))
            attr.inlinePresentationIntent = .stronglyEmphasized
            return attr

        case let emphasis as Emphasis:
            var attr = attributedString(from: childInlines(of: emphasis))
            attr.inlinePresentationIntent = .emphasized
            return attr

        case let code as InlineCode:
            var attr = AttributedString(code.code)
            attr.inlinePresentationIntent = .code
            attr.foregroundColor = Color(.contentSecondary)
            return attr

        case let link as Markdown.Link:
            var attr = attributedString(from: childInlines(of: link))
            if let destination = link.destination, let url = URL(string: destination) {
                attr.link = url
            }
            attr.foregroundColor = Color.accentColor
            attr.underlineStyle = .single
            return attr

        case is SoftBreak:
            return AttributedString(" ")

        case is LineBreak:
            return AttributedString("\n")

        case let strikethrough as Strikethrough:
            var attr = attributedString(from: childInlines(of: strikethrough))
            attr.strikethroughStyle = .single
            return attr

        default:
            return AttributedString(inline.plainText)
        }
    }

    private static func childInlines(of markup: any Markup) -> [any InlineMarkup] {
        markup.children.compactMap { $0 as? any InlineMarkup }
    }
}
