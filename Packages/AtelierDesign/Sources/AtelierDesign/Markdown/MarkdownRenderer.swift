import Foundation
import Markdown

/// Parses a markdown string into an array of `MarkdownBlock` values.
public struct MarkdownRenderer {
    private final class Entry {
        let blocks: [MarkdownBlock]
        init(_ blocks: [MarkdownBlock]) { self.blocks = blocks }
    }

    // NSCache is thread-safe but lacks Sendable conformance in the ObjC header.
    private nonisolated(unsafe) static let cache: NSCache<NSString, Entry> = {
        let cache = NSCache<NSString, Entry>()
        cache.countLimit = 256
        return cache
    }()

    public static func parse(_ source: String) -> [MarkdownBlock] {
        let key = source as NSString
        if let cached = cache.object(forKey: key) { return cached.blocks }

        let document = Document(parsing: source)
        var blocks: [MarkdownBlock] = []

        for child in document.children {
            guard let blockMarkup = child as? any BlockMarkup,
                  let block = convert(blockMarkup) else { continue }
            blocks.append(block)
        }

        cache.setObject(Entry(blocks), forKey: key)
        return blocks
    }

    /// Removes all cached parse results.
    public static func clearCache() {
        cache.removeAllObjects()
    }

    private static func convert(_ markup: any BlockMarkup) -> MarkdownBlock? {
        switch markup {
        case let paragraph as Paragraph:
            let attr = InlineText.attributedString(from: paragraph.inlineChildren)
            return .paragraph(attr)

        case let heading as Heading:
            let attr = InlineText.attributedString(from: heading.inlineChildren)
            return .heading(level: heading.level, attr)

        case let codeBlock as CodeBlock:
            let language = codeBlock.language?.trimmingCharacters(in: .whitespaces)
            let trimmedCode = codeBlock.code.hasSuffix("\n")
                ? String(codeBlock.code.dropLast())
                : codeBlock.code
            return .codeBlock(
                language: language?.isEmpty == true ? nil : language,
                code: trimmedCode
            )

        case let list as UnorderedList:
            let items = Array(list.listItems.map { item in
                InlineText.attributedString(from: inlines(in: item))
            })
            return .list(ordered: false, items: items)

        case let list as OrderedList:
            let items = Array(list.listItems.map { item in
                InlineText.attributedString(from: inlines(in: item))
            })
            return .list(ordered: true, items: items)

        case let blockQuote as BlockQuote:
            let text = blockQuote.children.compactMap { child -> AttributedString? in
                guard let paragraph = child as? Paragraph else { return nil }
                return InlineText.attributedString(from: paragraph.inlineChildren)
            }
            let combined = text.reduce(AttributedString()) { result, next in
                var r = result
                if !r.characters.isEmpty {
                    r.append(AttributedString("\n"))
                }
                r.append(next)
                return r
            }
            return .blockQuote(combined)

        case let table as Table:
            let headerCells = table.head.children.compactMap { $0 as? Table.Cell }
            let headers = headerCells.map { cell in
                InlineText.attributedString(from: cell.children.compactMap { $0 as? any InlineMarkup })
            }
            let bodyRows = table.body.children.compactMap { $0 as? Table.Row }
            let rows = bodyRows.map { row in
                let cells = row.children.compactMap { $0 as? Table.Cell }
                return cells.map { cell in
                    InlineText.attributedString(from: cell.children.compactMap { $0 as? any InlineMarkup })
                }
            }
            return .table(headers: headers, rows: rows)

        case is ThematicBreak:
            return .thematicBreak

        default:
            return nil
        }
    }

    private static func inlines(in listItem: ListItem) -> [any InlineMarkup] {
        listItem.children.compactMap { $0 as? Paragraph }.flatMap { paragraph in
            paragraph.children.compactMap { $0 as? any InlineMarkup }
        }
    }
}

private extension Heading {
    var inlineChildren: [any InlineMarkup] {
        children.compactMap { $0 as? any InlineMarkup }
    }
}

private extension Paragraph {
    var inlineChildren: [any InlineMarkup] {
        children.compactMap { $0 as? any InlineMarkup }
    }
}
