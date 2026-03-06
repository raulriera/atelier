import SwiftUI
import AtelierDesign
import AtelierKit

/// Timeline card for non-file tool calls (Bash, Grep, WebSearch, Agent, etc.).
///
/// Shows a plain-English description of the tool action with a spinner while
/// running and a disclosure chevron once completed output is available.
/// Tapping a completed card opens the inspector to show its result.
struct ToolUseCell: View {
    /// The tool event to display.
    let event: ToolUseEvent
    /// Whether this card is currently selected in the inspector.
    var isSelected: Bool = false
    /// Called when the user taps a completed card to inspect its output.
    var onSelect: ((ToolUseEvent) -> Void)?

    private var isTappable: Bool {
        event.status == .completed && event.hasResultOutput
    }

    var body: some View {
        Button {
            onSelect?(event)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Image(systemName: event.iconName)
                    .foregroundStyle(.contentTertiary)
                    .font(.cardBody)
                    .frame(width: 16, alignment: .center)

                Text(event.plainDescription)
                    .font(.cardBody)
                    .foregroundStyle(.contentSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer()

                if event.status == .running {
                    ElapsedTimeLabel(since: event.startedAt)
                    ProgressView()
                        .controlSize(.mini)
                } else if isTappable {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.contentTertiary)
                        .font(.metadata)
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plainUnfaded)
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
