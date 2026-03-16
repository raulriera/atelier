import SwiftUI
import AtelierDesign
import AtelierKit

/// Timeline card for tool approval requests.
///
/// Pending approvals show a full card with the tool description and
/// Approve/Deny buttons. Once resolved, the card collapses to a centered
/// one-line label indicating the outcome.
struct ApprovalCard: View {
    /// The approval event to display.
    let event: ApprovalEvent

    @Environment(\.timelineActions) private var actions

    var body: some View {
        switch event.status {
        case .pending:
            pendingCard
        case .approved:
            resolvedLabel(
                icon: "checkmark",
                style: .statusSuccess,
                verb: "Approved"
            )
        case .denied:
            resolvedLabel(
                icon: "xmark",
                style: .statusError,
                verb: "Denied"
            )
        case .dismissed:
            resolvedLabel(
                icon: "minus.circle",
                style: .contentSecondary,
                verb: "Dismissed"
            )
        }
    }

    // MARK: - Pending (full card with buttons)

    private var pendingCard: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Text(event.plainDescription)
                    .font(.cardTitle)

                Spacer()
            }

            if !event.inputSummary.isEmpty {
                Text(event.inputSummary)
                    .font(.conversationCode)
                    .foregroundStyle(.contentTertiary)
                    .lineLimit(3)
            }

            HStack(spacing: Spacing.xs) {
                Menu {
                    Button("Remember approval for the conversation") {
                        actions.onApprovalDecision?(event.id, event.toolName, .allowForSession)
                    }
                } label: {
                    Text("Approve")
                } primaryAction: {
                    actions.onApprovalDecision?(event.id, event.toolName, .allow)
                }
                .menuStyle(.glassProminent)
                .menuIndicator(.visible)

                Button("Deny") {
                    actions.onApprovalDecision?(event.id, event.toolName, .deny(reason: "User denied"))
                }
                .buttonStyle(.glass(.clear))
            }
            .padding(.top, Spacing.xxs)
        }
        .cardContainer()
        .transition(Motion.approvalAppear)
    }

    // MARK: - Resolved (compact one-liner)

    private func resolvedLabel(
        icon: String,
        style: some ShapeStyle,
        verb: String
    ) -> some View {
        Label("\(verb) \(event.displayName)", systemImage: icon)
            .systemContainer()
            .foregroundStyle(style)
            .frame(maxWidth: .infinity, alignment: .center)
            .transition(Motion.approvalAppear)
    }
}

#Preview("Approval Cards") {
    VStack(spacing: Spacing.md) {
        ApprovalCard(event: ApprovalEvent(
            id: "1",
            toolName: "Bash",
            inputJSON: #"{"command":"rm -rf ~/Documents/old-backups","description":"Delete old backup files"}"#,
            status: .pending
        ))

        ApprovalCard(event: ApprovalEvent(
            id: "2",
            toolName: "Write",
            inputJSON: #"{"file_path":"/Users/raul/Documents/Q2 Strategy/executive-summary.md"}"#,
            status: .pending
        ))

        ApprovalCard(event: ApprovalEvent(
            id: "3",
            toolName: "Edit",
            inputJSON: #"{"file_path":"/Users/raul/Desktop/meeting-notes.txt"}"#,
            status: .approved
        ))

        ApprovalCard(event: ApprovalEvent(
            id: "4",
            toolName: "Bash",
            inputJSON: #"{"command":"curl https://example.com/api","description":"Fetch data from example API"}"#,
            status: .denied
        ))

        ApprovalCard(event: ApprovalEvent(
            id: "5",
            toolName: "mcp__atelier-finder__finder_trash",
            inputJSON: #"{"path":"old-drafts"}"#,
            status: .approved
        ))
    }
    .padding()
    .frame(width: 500)
    .background(.surfaceDefault)
}
