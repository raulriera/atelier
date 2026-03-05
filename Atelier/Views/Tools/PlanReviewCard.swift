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
    /// Whether the user has already responded to this plan review.
    var isResolved: Bool = false
    /// Called when the user approves the plan — resolves the ExitPlanMode approval.
    var onApprove: (() -> Void)?

    @State private var planContent: String?
    @State private var showingPlan = false

    var body: some View {
        Group {
            if event.status == .running {
                runningRow
            } else if isResolved {
                resolvedLabel
            } else {
                completedCard
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

    // MARK: - Running (spinner row)

    private var runningRow: some View {
        HStack(spacing: Spacing.xs) {
            ProgressView()
                .controlSize(.mini)

            Text("Finishing plan…")
                .font(.cardBody)
                .foregroundStyle(.contentSecondary)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .transition(Motion.cardReveal)
    }

    // MARK: - Completed (compact card with buttons)

    private var completedCard: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text("Plan ready for review")
                .font(.cardTitle)

            Text("Review the plan, then approve or reply with feedback.")
                .font(.cardBody)
                .foregroundStyle(.contentSecondary)

            HStack(spacing: Spacing.sm) {
                Button("Approve") {
                    onApprove?()
                }
                .buttonStyle(.glassProminent)
                
                if planContent != nil {
                    Button("Review Plan") {
                        showingPlan = true
                    }
                    .buttonStyle(.glass)
                }
            }
            .padding(.top, Spacing.xxs)
        }
        .cardContainer()
        .transition(Motion.approvalAppear)
        .sheet(isPresented: $showingPlan) {
            if let planContent {
                PlanReviewSheet(planContent: planContent, onApprove: onApprove)
            }
        }
    }

    // MARK: - Resolved (compact one-liner)

    private var resolvedLabel: some View {
        Label("Reviewed plan", systemImage: "checkmark")
            .systemContainer()
            .foregroundStyle(.statusSuccess)
            .frame(maxWidth: .infinity, alignment: .center)
            .transition(Motion.approvalAppear)
    }
}

#Preview("Plan Review Card") {
    VStack(spacing: Spacing.md) {
        PlanReviewCard(event: ToolUseEvent(
            id: "1",
            name: "ExitPlanMode",
            status: .running
        ))

        PlanReviewCard(
            event: ToolUseEvent(
                id: "2",
                name: "ExitPlanMode",
                status: .completed
            ),
            planFilePath: "/tmp/example-plan.md"
        )

        PlanReviewCard(event: ToolUseEvent(
            id: "3",
            name: "ExitPlanMode",
            status: .completed
        ), isResolved: true)
    }
    .padding()
    .frame(width: 500)
    .background(.surfaceDefault)
}
