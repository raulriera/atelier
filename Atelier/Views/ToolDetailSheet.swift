import SwiftUI
import AtelierDesign
import AtelierKit

struct ToolDetailSheet: View {
    let event: ToolUseEvent

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(Spacing.md)

            Divider()

            ScrollView {
                Text(event.resultOutput)
                    .font(.conversationCode)
                    .foregroundStyle(.contentPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.md)
            }
        }
        .frame(minWidth: 480, idealWidth: 600, minHeight: 300)
        .presentationDetents([.medium, .large])
    }

    private var header: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: iconName)
                .foregroundStyle(.contentSecondary)

            Text(displayName)
                .font(.cardBody)

            if !event.inputSummary.isEmpty {
                Text(event.inputSummary)
                    .font(.conversationCode)
                    .foregroundStyle(.contentSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer()

            Button("Done") { dismiss() }
                .buttonStyle(.ghost)
        }
    }

    private var displayName: String {
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

    private var iconName: String {
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
