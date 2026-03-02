import SwiftUI
import AtelierDesign
import AtelierKit

struct ToolUseCell: View {
    let event: ToolUseEvent
    var onSelect: ((ToolUseEvent) -> Void)?

    private var isTappable: Bool {
        event.status == .completed && !event.resultOutput.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: iconName)
                    .foregroundStyle(.contentSecondary)

                Text(displayName)
                    .font(.cardBody)

                Spacer()

                if event.status == .running {
                    ProgressView()
                        .controlSize(.small)
                } else if isTappable {
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.contentTertiary)
                        .font(.caption)
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.statusSuccess)
                }
            }

            if !event.inputSummary.isEmpty {
                summaryText
                    .lineLimit(2)
            }

            if !event.resultSummary.isEmpty {
                Text(event.resultSummary)
                    .font(.conversationCode)
                    .foregroundStyle(.contentTertiary)
                    .lineLimit(2)
            }
        }
        .cardContainer()
        .contentShape(.rect)
        .onTapGesture {
            if isTappable { onSelect?(event) }
        }
        .transition(Motion.cardReveal)
    }

    @ViewBuilder
    private var summaryText: some View {
        if event.name == "Bash", let spaceIndex = event.inputSummary.firstIndex(of: " ") {
            let command = String(event.inputSummary[..<spaceIndex])
            let arguments = String(event.inputSummary[event.inputSummary.index(after: spaceIndex)...])
            Text("\(Text(command).font(.conversationCode).fontWeight(.semibold).foregroundStyle(.contentPrimary)) \(Text(arguments).font(.conversationCode).foregroundStyle(.contentSecondary))")
        } else {
            Text(event.inputSummary)
                .font(.conversationCode)
                .foregroundStyle(.contentSecondary)
        }
    }

    private var displayName: String {
        switch event.name {
        case "Bash":
            "Terminal Command"
        case "Read":
            "Read File"
        case "Write":
            "Write File"
        case "Edit":
            "Edit File"
        case "Glob":
            "Search Files"
        case "Grep":
            "Search Content"
        case "WebFetch":
            "Fetch Web Page"
        case "WebSearch":
            "Web Search"
        case "Agent":
            "Sub-agent"
        default:
            event.name
        }
    }

    private var iconName: String {
        switch event.name {
        case "Read":
            "doc.text"
        case "Write":
            "doc.badge.plus"
        case "Edit":
            "pencil"
        case "Bash":
            "terminal"
        case "Glob":
            "magnifyingglass"
        case "Grep":
            "text.magnifyingglass"
        case "WebFetch", "WebSearch":
            "globe"
        case "Agent":
            "person.2"
        default:
            "wrench"
        }
    }
}
