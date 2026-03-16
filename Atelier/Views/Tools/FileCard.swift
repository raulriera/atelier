import SwiftUI
import AtelierDesign
import AtelierKit

/// Timeline card for file operations (Read, Write, Edit).
///
/// Shows the file name and parent directory when available, falling back to
/// a plain-English description while the tool input is still streaming.
/// Completed Read/Edit cards open the inspector; Write cards reveal the
/// file in Finder.
struct FileCard: View {
    /// The file tool event to display.
    let event: ToolUseEvent
    /// Whether this card is currently selected in the inspector.
    var isSelected: Bool = false

    @Environment(\.timelineActions) private var actions

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

    /// The primary label: file name when available, plain description as fallback.
    private var displayText: String {
        if let name = event.fileName { return name }
        let summary = event.inputSummary
        return summary.isEmpty ? event.plainDescription : summary
    }

    var body: some View {
        Button(action: handleTap) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Image(systemName: event.iconName)
                    .foregroundStyle(.contentTertiary)
                    .font(.cardBody)
                    .frame(width: 16, alignment: .center)

                Text(displayText)
                    .font(.cardBody)
                    .foregroundStyle(.contentSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(event.fileDirectory ?? "")
                    .font(.cardBody)
                    .foregroundStyle(.contentTertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .opacity(event.fileDirectory != nil ? 1 : 0)

                Spacer()

                if event.status == .running {
                    ElapsedTimeLabel(since: event.startedAt)
                    ProgressView()
                        .controlSize(.mini)
                } else if isWriteOnly {
                    if isTappable {
                        Image(systemName: "finder")
                            .foregroundStyle(.contentTertiary)
                            .font(.metadata)
                    }
                } else {
                    if isTappable {
                        Text(operationLabel)
                            .font(.metadata)
                            .foregroundStyle(.contentTertiary)

                        Image(systemName: "chevron.right")
                            .foregroundStyle(.contentTertiary)
                            .font(.metadata)
                    }
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

    private func handleTap() {
        if isWriteOnly, let path = event.filePath {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
        } else {
            actions.onSelectTool?(event)
        }
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

        // Running state with no inputJSON yet (the bare case this fix addresses)
        FileCard(event: ToolUseEvent(
            id: "5",
            name: "Read",
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
