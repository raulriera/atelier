import SwiftUI
import AtelierDesign
import AtelierKit

/// Timeline card for plan review (ExitPlanMode).
///
/// Shows a compact card with a "Review Plan" button that opens the full
/// plan in a sheet, plus an Approve button that resolves the pending
/// ExitPlanMode approval. After resolution, collapses to a compact label.
struct PlanReviewCard: View {
    /// The ExitPlanMode tool event.
    let event: ToolUseEvent
    /// Path to the plan file on disk, resolved by the session.
    var planFilePath: String?
    /// The resolution status — `.pending` until the user decides.
    var resolution: ApprovalEvent.Status

    @Environment(\.timelineActions) private var actions
    @State private var planContent: String?
    @State private var showingPlan = false

    var body: some View {
        Group {
            switch resolution {
            case .pending:
                completedCard
            case .approved, .denied, .dismissed:
                resolvedLabel(status: resolution)
            }
        }
        .task(id: planFilePath) {
            guard let path = planFilePath else {
                planContent = nil
                return
            }
            planContent = try? String(contentsOfFile: path, encoding: .utf8)
        }
    }

    // MARK: - Pending (compact card with button)

    private var completedCard: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Plan ready for review")
                .font(.cardTitle)

            Text("Review the plan, then approve or reply with feedback.")
                .font(.cardBody)
                .foregroundStyle(.contentSecondary)

            Button("Review Plan") {
                showingPlan = true
            }
            .buttonStyle(.glassProminent)
            .padding(.top, Spacing.xxs)
        }
        .cardContainer()
        .transition(Motion.approvalAppear)
        .sheet(isPresented: $showingPlan) {
            PlanReviewSheet(
                planContent: planContent ?? "",
                onApprove: actions.onPlanApprove
            )
        }
    }

    // MARK: - Resolved (compact one-liner)

    @ViewBuilder
    private func resolvedLabel(status: ApprovalEvent.Status) -> some View {
        switch status {
        case .approved:
            statusLabel("Plan approved", icon: "checkmark", style: .statusSuccess)
        case .denied:
            statusLabel("Changes requested", icon: "arrow.uturn.backward", style: .contentSecondary)
        case .dismissed:
            statusLabel("Plan dismissed", icon: "minus.circle", style: .contentSecondary)
        case .pending:
            EmptyView()
        }
    }

    private func statusLabel(_ text: String, icon: String, style: some ShapeStyle) -> some View {
        Label(text, systemImage: icon)
            .systemContainer()
            .foregroundStyle(style)
            .frame(maxWidth: .infinity, alignment: .center)
            .transition(Motion.approvalAppear)
    }
}

#Preview("Plan Review Card") {
    VStack(spacing: Spacing.md) {
        PlanReviewCard(
            event: ToolUseEvent(
                id: "1",
                name: "ExitPlanMode",
                status: .running
            ),
            planFilePath: "/tmp/example-plan.md",
            resolution: .pending
        )

        PlanReviewCard(event: ToolUseEvent(
            id: "3",
            name: "ExitPlanMode",
            status: .completed
        ), resolution: .approved)

        PlanReviewCard(event: ToolUseEvent(
            id: "4",
            name: "ExitPlanMode",
            status: .completed
        ), resolution: .denied)

        PlanReviewCard(event: ToolUseEvent(
            id: "5",
            name: "ExitPlanMode",
            status: .completed
        ), resolution: .dismissed)
    }
    .padding()
    .frame(width: 500)
    .background(.surfaceDefault)
}
