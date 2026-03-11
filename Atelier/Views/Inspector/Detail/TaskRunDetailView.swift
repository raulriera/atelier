import SwiftUI
import AtelierDesign
import AtelierKit

/// Inspector detail for a completed scheduled task, showing health, diagnostics, and output.
struct TaskRunDetailView: View {
    let event: TaskCompletionEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.top, Spacing.md)
                .padding(.horizontal, Spacing.md)

            ScrollView {
                diagnostics
                    .padding(Spacing.md)
            }
        }
    }

    private var header: some View {
        let health = event.result.health
        return VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: health.iconName)
                    .foregroundStyle(.primary)

                Text(event.name)
                    .font(.cardBody)
            }

            Text(event.result.date.formatted(.relative(presentation: .named)))
                .font(.metadata)
                .foregroundStyle(.contentTertiary)
        }
    }

    private var diagnostics: some View {
        let result = event.result
        return VStack(alignment: .leading, spacing: Spacing.md) {

            if let detail = result.userDetail {
                Text(detail)
                    .font(.body)
                    .foregroundStyle(.contentSecondary)
            }

            Divider()

            VStack(alignment: .leading, spacing: Spacing.xs) {
                diagnosticRow("Duration") {
                    Text(Duration.milliseconds(result.durationMs), format: .units(allowed: [.minutes, .seconds], zeroValueUnits: .hide))
                }

                if !result.permissionDenials.isEmpty {
                    diagnosticRow("Blocked capabilities") {
                        Text(result.permissionDenials.joined(separator: ", "))
                    }
                }

                if !result.resultText.isEmpty {
                    Text("Description")
                        .font(.metadata)
                        .foregroundStyle(.contentTertiary)

                    Text(result.resultText)
                        .font(.conversationCode)
                        .foregroundStyle(.contentSecondary)
                        .textSelection(.enabled)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func diagnosticRow(_ label: String, @ViewBuilder value: () -> some View) -> some View {
        HStack {
            Text(label)
                .font(.metadata)
                .foregroundStyle(.contentTertiary)
            Spacer()
            value()
                .font(.metadata)
                .foregroundStyle(.contentSecondary)
        }
    }
}

#Preview("Healthy") {
    TaskRunDetailView(event: TaskCompletionEvent(
        name: "Daily standup summary",
        result: TaskRunResult(
            date: Date().addingTimeInterval(-3600),
            succeeded: true,
            numTurns: 4,
            resultText: "Generated standup summary and posted to #team-updates.",
            permissionDenials: [],
            durationMs: 12400,
            health: .healthy,
            userSummary: "completed successfully",
            userDetail: "Summarized 3 PRs and 2 issues from the last 24 hours."
        )
    ))
    .frame(width: 320, height: 500)
}

#Preview("Warning") {
    TaskRunDetailView(event: TaskCompletionEvent(
        name: "Code review digest",
        result: TaskRunResult(
            date: Date().addingTimeInterval(-7200),
            succeeded: true,
            numTurns: 8,
            resultText: "Partial review completed.",
            permissionDenials: ["Bash"],
            durationMs: 45000,
            health: .warning,
            userSummary: "completed with warnings",
            userDetail: "Some tools were blocked during execution."
        )
    ))
    .frame(width: 320, height: 500)
}

#Preview("Failed") {
    TaskRunDetailView(event: TaskCompletionEvent(
        name: "Nightly backup check",
        result: TaskRunResult(
            date: Date().addingTimeInterval(-600),
            succeeded: false,
            numTurns: 1,
            resultText: "",
            permissionDenials: ["Read", "Bash"],
            durationMs: 2100,
            health: .failed,
            userSummary: "failed to complete",
            userDetail: "Could not access backup directory."
        )
    ))
    .frame(width: 320, height: 500)
}
