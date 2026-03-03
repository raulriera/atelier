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
                Text(event.resultOutput.isEmpty ? event.resultSummary : event.resultOutput)
                    .font(.conversationCode)
                    .foregroundStyle(.contentPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.md)
            }
        }
    }

    private func header(for event: ToolUseEvent) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: iconName(for: event))
                .foregroundStyle(.contentSecondary)

            Text(displayName(for: event))
                .font(.cardBody)

            if !event.inputSummary.isEmpty {
                Text(event.inputSummary)
                    .font(.conversationCode)
                    .foregroundStyle(.contentSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Selection", systemImage: "sidebar.right")
        } description: {
            Text("Select a tool card to inspect its output")
        }
    }

    private func displayName(for event: ToolUseEvent) -> String {
        switch event.name {
        case "Bash": "Terminal Command"
        case "Read": "Read File"
        case "Write": "Write File"
        case "Edit": "Edit File"
        case "Glob": "Search Files"
        case "Grep": "Search Content"
        case "WebFetch": "Fetch Web Page"
        case "WebSearch": "Web Search"
        case "Agent": "Sub-agent"
        default: event.name
        }
    }

    private func iconName(for event: ToolUseEvent) -> String {
        switch event.name {
        case "Read": "doc.text"
        case "Write": "doc.badge.plus"
        case "Edit": "pencil"
        case "Bash": "terminal"
        case "Glob": "magnifyingglass"
        case "Grep": "text.magnifyingglass"
        case "WebFetch", "WebSearch": "globe"
        case "Agent": "person.2"
        default: "wrench"
        }
    }
}
