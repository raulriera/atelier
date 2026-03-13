import SwiftUI

/// Renders a fenced code block with syntax label and copy button.
public struct CodeBlockView: View {
    let language: String?
    let code: String

    @State private var isHovering = false
    @State private var copied = false

    public init(language: String?, code: String) {
        self.language = language
        self.code = code
    }

    /// Whether this code block should render with diff coloring.
    private var isDiff: Bool {
        guard let language else { return false }
        if language.lowercased() == "diff" { return true }
        // Heuristic: any block where most lines start with +/- is a diff
        let lines = code.split(separator: "\n", omittingEmptySubsequences: false)
        let diffLines = lines.filter { $0.hasPrefix("+ ") || $0.hasPrefix("- ") || $0.hasPrefix("+\t") || $0.hasPrefix("-\t") }
        return lines.count >= 2 && diffLines.count * 2 >= lines.count
    }

    private var diffContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            let lines = code.split(separator: "\n", omittingEmptySubsequences: false)
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                let lineStr = String(line)
                Text(lineStr)
                    .font(.conversationCode)
                    .foregroundStyle(diffForeground(for: lineStr))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, 1)
                    .background(diffBackground(for: lineStr), in: .rect)
            }
        }
        .textSelection(.enabled)
        .padding(.vertical, Spacing.sm)
    }

    private func diffForeground(for line: String) -> some ShapeStyle {
        if line.hasPrefix("+") {
            return AnyShapeStyle(.statusSuccess)
        } else if line.hasPrefix("-") {
            return AnyShapeStyle(.statusError)
        }
        return AnyShapeStyle(.contentPrimary)
    }

    private func diffBackground(for line: String) -> some ShapeStyle {
        if line.hasPrefix("+") {
            return AnyShapeStyle(.statusSuccess.opacity(0.1))
        } else if line.hasPrefix("-") {
            return AnyShapeStyle(.statusError.opacity(0.1))
        }
        return AnyShapeStyle(.clear)
    }

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
                diffContent
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
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        copied = false
                    }
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
            }
        }
        .onHover { hovering in
            withAnimation(Motion.settle) {
                isHovering = hovering
            }
        }
    }
}
