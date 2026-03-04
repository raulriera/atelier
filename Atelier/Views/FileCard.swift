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
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: event.iconName)
                        .foregroundStyle(.contentSecondary)

                    Text(event.fileName ?? event.inputSummary)
                        .font(.cardBody)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    if event.status == .running {
                        ProgressView()
                            .controlSize(.small)
                    } else if isWriteOnly {
                        if isTappable {
                            Image(systemName: "finder")
                                .foregroundStyle(.contentTertiary)
                        }
                    } else {
                        Text(operationLabel)
                            .font(.metadata)
                            .foregroundStyle(.contentTertiary)

                        if isTappable {
                            Image(systemName: "chevron.right")
                                .foregroundStyle(.contentTertiary)
                                .font(.caption)
                        }
                    }
                }

                if let dir = event.fileDirectory {
                    Text(dir)
                        .font(.metadata)
                        .foregroundStyle(.contentTertiary)
                        .lineLimit(1)
                        .truncationMode(.head)
                }
            }
            .cardContainer()
        }
        .buttonStyle(.plain)
        .disabled(!isTappable)
        .overlay {
            RoundedRectangle(cornerRadius: Radii.md, style: .continuous)
                .strokeBorder(.contentAccent, lineWidth: 1.5)
                .opacity(isSelected ? 1 : 0)
        }
        .animation(Motion.morph, value: isSelected)
        .transition(Motion.cardReveal)
    }
}

#Preview("File Cards") {
    VStack(spacing: Spacing.sm) {
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
