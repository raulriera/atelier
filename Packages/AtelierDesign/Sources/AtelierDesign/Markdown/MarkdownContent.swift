import SwiftUI

/// Renders a markdown string as rich SwiftUI content.
///
/// Parses the source with `swift-markdown` and renders each block
/// as a native SwiftUI view. Code blocks get special styling with
/// copy buttons; inline markup (bold, italic, code, links) renders
/// via `AttributedString`.
///
/// Usage:
/// ```swift
/// MarkdownContent(source: message.text)
/// ```
public struct MarkdownContent: View {
    let source: String

    public init(source: String) {
        self.source = source
    }

    private var blocks: [MarkdownBlock] {
        MarkdownRenderer.parse(source)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ForEach(blocks, id: \.self) { block in
                blockView(for: block)
            }
        }
    }

    @ViewBuilder
    private func blockView(for block: MarkdownBlock) -> some View {
        switch block {
        case .paragraph(let text):
            Text(text)
                .font(.conversationBody)
                .foregroundStyle(.contentPrimary)
                .textSelection(.enabled)

        case .heading(let level, let text):
            Text(text)
                .font(headingFont(for: level))
                .foregroundStyle(.contentPrimary)
                .textSelection(.enabled)
                .padding(.top, level <= 2 ? Spacing.xs : 0)

        case .codeBlock(let language, let code):
            CodeBlockView(language: language, code: code)

        case .list(let ordered, let items):
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                        Text(ordered ? "\(index + 1)." : "\u{2022}")
                            .font(.conversationBody)
                            .foregroundStyle(.contentSecondary)
                        Text(item)
                            .font(.conversationBody)
                            .foregroundStyle(.contentPrimary)
                            .textSelection(.enabled)
                    }
                }
            }

        case .blockQuote(let text):
            HStack(spacing: Spacing.sm) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.contentTertiary)
                    .frame(width: 3)
                Text(text)
                    .font(.conversationBody)
                    .foregroundStyle(.contentSecondary)
                    .textSelection(.enabled)
            }

        case .table(let headers, let rows):
            Grid(alignment: .leading, horizontalSpacing: Spacing.md, verticalSpacing: Spacing.xxs) {
                GridRow {
                    ForEach(Array(headers.enumerated()), id: \.offset) { _, header in
                        Text(header)
                            .font(.conversationBody)
                            .fontWeight(.semibold)
                            .foregroundStyle(.contentSecondary)
                    }
                }

                Divider()

                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            Text(cell)
                                .font(.conversationBody)
                                .foregroundStyle(.contentPrimary)
                                .textSelection(.enabled)
                        }
                    }
                }
            }

        case .thematicBreak:
            Divider()
                .padding(.vertical, Spacing.xs)
        }
    }

    private func headingFont(for level: Int) -> Font {
        switch level {
        case 1: .title
        case 2: .title2
        case 3: .title3
        default: .headline
        }
    }
}
