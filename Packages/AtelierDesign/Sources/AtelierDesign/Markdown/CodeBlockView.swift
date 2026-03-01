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

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let language, !language.isEmpty {
                HStack {
                    Spacer()
                    Text(language)
                        .font(.metadata)
                        .foregroundStyle(.contentSecondary)
                        .padding(.trailing, Spacing.sm)
                        .padding(.top, Spacing.xs)
                }
            }

            Text(code)
                .font(.conversationCode)
                .foregroundStyle(.contentPrimary)
                .textSelection(.enabled)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
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
