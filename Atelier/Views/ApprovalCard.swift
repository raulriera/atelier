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
                Image(systemName: "exclamationmark.shield")
                    .foregroundStyle(.statusWarning)

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
