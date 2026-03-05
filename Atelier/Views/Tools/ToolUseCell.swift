import SwiftUI
import AtelierDesign
import AtelierKit

struct ToolUseCell: View {
    let event: ToolUseEvent
    var isSelected: Bool = false
    var onSelect: ((ToolUseEvent) -> Void)?

    private var isTappable: Bool {
        event.status == .completed && event.hasResultOutput
    }

    var body: some View {
        Button {
            onSelect?(event)
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: event.iconName)
                    .foregroundStyle(.contentTertiary)
                    .font(.caption)

                Text(event.plainDescription)
                    .font(.metadata)
                    .foregroundStyle(.contentSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                if event.status == .running {
                    ProgressView()
                        .controlSize(.mini)
                } else if isTappable {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.contentTertiary)
                        .font(.caption2)
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isTappable)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: Radii.sm, style: .continuous)
                    .fill(.contentSecondary.opacity(0.1))
            }
        }
        .animation(Motion.morph, value: isSelected)
        .transition(Motion.cardReveal)
    }

}

#Preview("Tool Use Cells") {
    VStack(alignment: .leading, spacing: Spacing.xxs) {
        ToolUseCell(event: ToolUseEvent(
            id: "1",
            name: "WebSearch",
            inputJSON: #"{"query":"Raul Riera"}"#,
            status: .completed,
            resultOutput: "Web search results for query: \"Raul Riera\""
        ))

        ToolUseCell(event: ToolUseEvent(
            id: "2",
            name: "Bash",
            inputJSON: #"{"command":"ls -la ~/Documents","description":"List files in Documents folder"}"#,
            status: .completed,
            resultOutput: "total 42\ndrwxr-xr-x  5 raul staff..."
        ))

        ToolUseCell(event: ToolUseEvent(
            id: "3",
            name: "Grep",
            inputJSON: #"{"pattern":"TODO","path":"/Users/raul/project"}"#,
            status: .running
        ))

        ToolUseCell(event: ToolUseEvent(
            id: "4",
            name: "Glob",
            inputJSON: #"{"pattern":"**/*.swift"}"#,
            status: .completed,
            resultOutput: "Found 42 files"
        ), isSelected: true)
    }
    .padding()
    .frame(width: 500)
    .background(.surfaceDefault)
}
