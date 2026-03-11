import SwiftUI
import AtelierDesign
import AtelierKit

/// Inspector detail for a tool use event, showing the tool's header and result output.
struct ToolDetailView: View {
    let event: ToolUseEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(Spacing.md)

            Divider()

            ScrollView {
                resultView
                    .padding(Spacing.md)
            }
        }
    }

    private var header: some View {
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
    private var resultView: some View {
        if let oldText = event.editOldString,
           let newText = event.editNewString {
            ChangePreview(oldText: oldText, newText: newText)
        } else if event.isFileOperation && event.fileType == .markdown {
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
}

#Preview("File edit") {
    ToolDetailView(event: ToolUseEvent(
        id: "edit-1",
        name: "Edit",
        inputJSON: """
        {"file_path":"/src/App.swift","old_string":"let x = 1","new_string":"let x = 2"}
        """,
        status: .completed,
        resultOutput: "File edited successfully"
    ))
    .frame(width: 320, height: 400)
}

#Preview("Terminal command") {
    ToolDetailView(event: ToolUseEvent(
        id: "bash-1",
        name: "Bash",
        inputJSON: """
        {"command":"swift build"}
        """,
        status: .completed,
        resultOutput: "Build complete! (0.42s)"
    ))
    .frame(width: 320, height: 400)
}
