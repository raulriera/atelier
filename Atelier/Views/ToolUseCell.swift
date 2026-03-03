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
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: event.iconName)
                        .foregroundStyle(.contentSecondary)

                    Text(event.displayName)
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

}
