import SwiftUI

/// Renders a fenced code block with syntax label and copy button.
public struct CodeBlockView: View {
    let language: String?
    let code: String

    @State private var isHovering = false
    @State private var copied = false

    /// Pre-computed diff lines. Empty when the block is not a diff.
    private let diffLines: [DiffLine]

    public init(language: String?, code: String) {
        self.language = language
        self.code = code
        self.diffLines = Self.parseDiffLines(language: language, code: code)
    }

    /// Whether this code block should render with diff coloring.
    private var isDiff: Bool { !diffLines.isEmpty }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language, !language.isEmpty {
                Text(language)
                    .font(.metadata)
                    .foregroundStyle(.contentSecondary)
                    .padding(.leading, Spacing.md)
                    .padding(.top, Spacing.xs)
            }

            if isDiff {
                DiffContentView(lines: diffLines)
            } else {
                Text(code)
                    .font(.conversationCode)
                    .foregroundStyle(.contentPrimary)
                    .textSelection(.enabled)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(.surfaceCode, in: .rect(cornerRadius: Radii.md, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if isHovering {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    copied = true
                } label: {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                        .foregroundStyle(.contentSecondary)
                        .contentTransition(.symbolEffect(.replace))
                        .padding(Spacing.xs)
                        .background(.surfaceElevated, in: .rect(cornerRadius: Radii.sm, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(Spacing.xs)
                .transition(.opacity)
                .accessibilityLabel(copied ? "Copied" : "Copy code")
            }
        }
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
        .onHover { hovering in
            withAnimation(Motion.settle) {
                isHovering = hovering
            }
        }
    }

    // MARK: - Diff Parsing

    /// Parses code into colored diff lines, or returns empty if not a diff.
    private static func parseDiffLines(language: String?, code: String) -> [DiffLine] {
        let lines = code.split(separator: "\n", omittingEmptySubsequences: false)

        let explicitDiff = language?.lowercased() == "diff"
        if !explicitDiff {
            guard let language, !language.isEmpty else { return [] }
            // Heuristic: most lines start with +/-
            let diffCount = lines.filter { $0.hasPrefix("+") || $0.hasPrefix("-") }.count
            guard lines.count >= 2, diffCount * 2 >= lines.count else { return [] }
        }

        return lines.enumerated().map { index, line in
            let text = String(line)
            if text.hasPrefix("+") {
                return DiffLine(id: index, text: text, foreground: AnyShapeStyle(.statusSuccess), background: AnyShapeStyle(.statusSuccess.opacity(0.12)))
            } else if text.hasPrefix("-") {
                return DiffLine(id: index, text: text, foreground: AnyShapeStyle(.statusError), background: AnyShapeStyle(.statusError.opacity(0.12)))
            }
            return DiffLine(id: index, text: text, foreground: AnyShapeStyle(.contentPrimary), background: AnyShapeStyle(.clear))
        }
    }
}

// MARK: - Diff Subviews

/// Extracted subview so hover/copy state changes in `CodeBlockView` don't
/// re-evaluate the diff line layout (inputs are stable `let` values).
private struct DiffContentView: View {
    let lines: [DiffLine]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(lines) { line in
                Text(line.text)
                    .font(.conversationCode)
                    .foregroundStyle(line.foreground)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, 1)
                    .background(line.background, in: .rect)
            }
        }
        .textSelection(.enabled)
        .padding(.vertical, Spacing.sm)
    }
}

private struct DiffLine: Identifiable {
    let id: Int
    let text: String
    let foreground: AnyShapeStyle
    let background: AnyShapeStyle
}
