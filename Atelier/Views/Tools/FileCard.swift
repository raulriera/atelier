import SwiftUI
import AtelierDesign
import AtelierKit

struct FileCard: View {
    let event: ToolUseEvent
    var isSelected: Bool = false
    var onSelect: ((ToolUseEvent) -> Void)?

    /// Write cards reveal in Finder; Read/Edit cards open the inspector.
    private var isWriteOnly: Bool {
        event.name == "Write"
    }

    private var isTappable: Bool {
        guard event.status == .completed else { return false }
        if isWriteOnly { return event.filePath != nil }
        return event.hasResultOutput
    }

    private var operationLabel: String {
        switch event.name {
        case "Read": "Read"
        case "Write": "Write"
        case "Edit": "Edit"
        default: event.name
        }
    }

    var body: some View {
        Button {
            if isWriteOnly, let path = event.filePath {
                NSWorkspace.shared.activateFileViewerSelecting(
                    [URL(fileURLWithPath: path)]
                )
            } else {
                onSelect?(event)
            }
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: event.iconName)
                    .foregroundStyle(.contentTertiary)
                    .font(.caption)

                Text(event.fileName ?? event.inputSummary)
                    .font(.metadata)
                    .foregroundStyle(.contentSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let dir = event.fileDirectory {
                    Text(dir)
                        .font(.metadata)
                        .foregroundStyle(.contentTertiary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }

                Spacer()

                if event.status == .running {
                    ProgressView()
                        .controlSize(.mini)
                } else if isWriteOnly {
                    if isTappable {
                        Image(systemName: "finder")
                            .foregroundStyle(.contentTertiary)
                            .font(.caption2)
                    }
                } else {
                    if isTappable {
                        Text(operationLabel)
                            .font(.metadata)
                            .foregroundStyle(.contentTertiary)

                        Image(systemName: "chevron.right")
                            .foregroundStyle(.contentTertiary)
                            .font(.caption2)
                    }
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

#Preview("File Cards") {
    VStack(alignment: .leading, spacing: Spacing.xxs) {
        FileCard(event: ToolUseEvent(
            id: "1",
            name: "Read",
            inputJSON: #"{"file_path":"/Users/raul/Documents/Q2 Strategy/competitive-analysis.md"}"#,
            status: .completed,
            resultOutput: "# Competitive Analysis\n\nKey findings from market research..."
        ))

        FileCard(event: ToolUseEvent(
            id: "2",
            name: "Write",
            inputJSON: #"{"file_path":"/Users/raul/Documents/Q2 Strategy/executive-summary.md"}"#,
            status: .completed,
            resultOutput: "# Executive Summary\n\nThis document outlines..."
        ))

        FileCard(event: ToolUseEvent(
            id: "3",
            name: "Edit",
            inputJSON: #"{"file_path":"/Users/raul/Desktop/meeting-notes.txt"}"#,
            status: .running
        ))

        FileCard(event: ToolUseEvent(
            id: "4",
            name: "Read",
            inputJSON: #"{"file_path":"/Users/raul/Documents/Q2 Strategy/budget-proposal.md"}"#,
            status: .completed,
            resultOutput: "# Budget Proposal\n\nProjected spend for Q2..."
        ), isSelected: true)
    }
    .padding()
    .frame(width: 500)
    .background(.surfaceDefault)
}
