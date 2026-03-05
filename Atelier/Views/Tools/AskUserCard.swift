import SwiftUI
import AtelierDesign
import AtelierKit

/// Timeline card for ask-user questions with selectable options.
///
/// Pending questions show the full question text with option buttons and an
/// expandable "Other" free-text field. Once answered, the card collapses
/// to a centered one-line label showing the selected option.
struct AskUserCard: View {
    /// The ask-user event to display.
    let event: AskUserEvent
    /// Called when the user selects an option: `(eventID, selectedIndex, customText?)`.
    var onResponse: ((String, Int, String?) -> Void)?

    @State private var isOtherExpanded = false
    @State private var otherText = ""
    @FocusState private var isOtherFocused: Bool

    var body: some View {
        switch event.status {
        case .pending:
            pendingCard
        case .answered:
            resolvedLabel
        }
    }

    // MARK: - Pending (question with option buttons)

    private var pendingCard: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(event.question)
                .font(.cardTitle)

            VStack(spacing: Spacing.xxs) {
                ForEach(Array(event.options.enumerated()), id: \.offset) { index, option in
                    Button {
                        onResponse?(event.id, index, nil)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(option.label)
                            if let description = option.description, !description.isEmpty {
                                Text(description)
                                    .font(.conversationCode)
                                    .foregroundStyle(.contentSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.glass(.clear))
                }

                if isOtherExpanded {
                    HStack(spacing: Spacing.xs) {
                        TextField("Type your answer...", text: $otherText)
                            .textFieldStyle(.plain)
                            .focused($isOtherFocused)
                            .onSubmit { submitOther() }

                        Button("Submit") { submitOther() }
                            .buttonStyle(.glass(.clear))
                            .disabled(otherText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(Spacing.xs)
                    .background(.fill.quaternary, in: .rect(cornerRadius: Radii.sm))
                } else {
                    Button {
                        isOtherExpanded = true
                        isOtherFocused = true
                    } label: {
                        Text("Other")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.glass(.clear))
                }
            }
        }
        .cardContainer()
        .transition(Motion.approvalAppear)
    }

    // MARK: - Answered (compact one-liner)

    private var resolvedLabel: some View {
        Label(
            "Selected: \(event.selectedLabel ?? "Unknown")",
            systemImage: "checkmark.bubble"
        )
        .systemContainer()
        .foregroundStyle(.statusSuccess)
        .frame(maxWidth: .infinity, alignment: .center)
        .transition(Motion.approvalAppear)
    }

    private func submitOther() {
        let trimmed = otherText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onResponse?(event.id, AskUserEvent.customTextIndex, trimmed)
    }
}

#Preview("AskUser Cards") {
    VStack(spacing: Spacing.md) {
        AskUserCard(event: AskUserEvent(
            id: "1",
            question: "Which format should I use for your notes?",
            options: [
                .init(label: "Markdown", description: "Rich formatting with headers, lists, and links"),
                .init(label: "Plain Text", description: "Simple, universal, no formatting"),
                .init(label: "Rich Text", description: "WYSIWYG formatting with fonts and colors"),
            ]
        ))

        AskUserCard(event: AskUserEvent(
            id: "2",
            question: "Which format should I use for your notes?",
            options: [
                .init(label: "Markdown", description: "Rich formatting"),
                .init(label: "Plain Text", description: nil),
                .init(label: "Rich Text", description: nil),
            ],
            selectedIndex: 0,
            status: .answered,
            answeredAt: Date()
        ))

        AskUserCard(event: AskUserEvent(
            id: "3",
            question: "What name should the file have?",
            options: [
                .init(label: "notes.md", description: nil),
                .init(label: "document.md", description: nil),
            ],
            selectedIndex: AskUserEvent.customTextIndex,
            customText: "my-custom-name.md",
            status: .answered,
            answeredAt: Date()
        ))
    }
    .padding()
    .frame(width: 500)
    .background(.surfaceDefault)
}
