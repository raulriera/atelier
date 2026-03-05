import SwiftUI
import AtelierDesign

/// Sheet that renders the full plan markdown for comfortable reading.
///
/// Presented from `PlanReviewCard` when the user taps "Review Plan".
/// Contains the rendered plan in a scrollable area with an Approve
/// action at the bottom.
struct PlanReviewSheet: View {
    /// The full plan markdown content.
    let planContent: String
    /// Called when the user approves the plan.
    var onApprove: (() -> Void)?

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                MarkdownContent(source: planContent)
                    .padding(Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            HStack {
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.glass)

                Spacer()

                Button("Approve") {
                    onApprove?()
                    dismiss()
                }
                .buttonStyle(.glassProminent)
            }
            .padding(Spacing.md)
        }
        .frame(minWidth: 560, idealWidth: 640, minHeight: 400, idealHeight: 700)
    }
}

#Preview("Plan Review Sheet") {
    PlanReviewSheet(
        planContent: """
        # Implementation Plan

        ## Summary
        Add a new feature to the project that improves user experience.

        ## Steps
        1. Update the data model with new fields
        2. Create the view components
        3. Wire up the navigation flow
        4. Add unit tests

        ## Files to modify
        - `Models/User.swift` — add new properties
        - `Views/ProfileView.swift` — update layout
        - `Tests/UserTests.swift` — add coverage

        ## Notes
        This is a **low-risk** change that only affects the profile screen.
        No migration needed since the new fields are optional.
        """
    )
}
