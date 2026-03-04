import SwiftUI
import AtelierDesign
import AtelierKit

struct ApprovalCard: View {
    let event: ApprovalEvent
    var onDecision: ((String, ApprovalDecision) -> Void)?

    var body: some View {
        switch event.status {
        case .pending:
            pendingCard
        case .approved:
            resolvedLabel(
                icon: "checkmark.circle.fill",
                style: .statusSuccess,
                verb: "Approved"
            )
        case .denied:
            resolvedLabel(
                icon: "xmark.circle.fill",
                style: .statusError,
                verb: "Denied"
            )
        }
    }

    // MARK: - Pending (full card with buttons)

    private var pendingCard: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.xs) {
                Text("Claude wants to \(event.displayName)")
                    .font(.cardBody)

                Spacer()
            }

            if !event.inputSummary.isEmpty {
                Text(event.inputSummary)
                    .font(.conversationCode)
                    .foregroundStyle(.contentSecondary)
                    .lineLimit(3)
            }

            HStack(spacing: Spacing.xs) {
                Button("Approve") {
                    onDecision?(event.id, .allow)
                }
                .buttonStyle(.glassProminent)

                Button("Deny") {
                    onDecision?(event.id, .deny(reason: "User denied"))
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
            inputJSON: #"{"command":"rm -rf ~/Documents/old-backups"}"#,
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
            inputJSON: #"{"command":"curl https://example.com/api"}"#,
            status: .denied
        ))
    }
    .padding()
    .frame(width: 500)
    .background(.surfaceDefault)
}
