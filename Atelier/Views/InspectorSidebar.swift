import SwiftUI
import AtelierDesign
import AtelierKit

struct InspectorSidebar: View {
    let selectedTool: ToolUseEvent?

    var body: some View {
        if let event = selectedTool {
            toolDetail(for: event)
        } else {
            emptyState
        }
    }

    private func toolDetail(for event: ToolUseEvent) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header(for: event)
                .padding(Spacing.md)

            Divider()

            ScrollView {
                resultView(for: event)
                    .padding(Spacing.md)
            }
        }
    }

    private func header(for event: ToolUseEvent) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: event.iconName)
                    .foregroundStyle(.contentSecondary)

                Text(event.fileName ?? event.displayName)
                    .font(.cardBody)

                Spacer()

                Text(event.displayName)
                    .font(.metadata)
                    .foregroundStyle(.contentTertiary)
            }

            if let dir = event.fileDirectory {
                Text(dir)
                    .font(.metadata)
                    .foregroundStyle(.contentTertiary)
                    .lineLimit(1)
                    .truncationMode(.head)
            } else if !event.inputSummary.isEmpty, !event.isFileOperation {
                Text(event.inputSummary)
                    .font(.conversationCode)
                    .foregroundStyle(.contentSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    @ViewBuilder
    private func resultView(for event: ToolUseEvent) -> some View {
        if event.isFileOperation && event.fileType == .markdown {
            MarkdownContent(source: event.fileContent)
        } else {
            let content = event.isFileOperation
                ? event.fileContent
                : (event.resultOutput.isEmpty ? event.resultSummary : event.resultOutput)
            Text(content)
                .font(.conversationCode)
                .foregroundStyle(.contentPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Selection", systemImage: "sidebar.right")
        } description: {
            Text("Select a tool card to inspect its output")
        }
    }
}
