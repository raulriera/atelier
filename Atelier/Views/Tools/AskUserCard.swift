import SwiftUI
import AtelierDesign
import AtelierKit

/// Timeline card for ask-user questions with selectable options.
///
/// Pending questions show the question text with a radio group picker for
/// the options and a hint that the user can type a message instead. Once
/// answered, the card collapses to a centered one-line label.
struct AskUserCard: View {
    /// The ask-user event to display.
    let event: AskUserEvent

    @Environment(\.timelineActions) private var actions
    @State private var selection: Int?

    var body: some View {
        switch event.status {
        case .pending:
            pendingCard
        case .answered:
            resolvedLabel
        }
    }

    // MARK: - Pending (question with radio picker)

    private var pendingCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(event.question)
                .font(.cardTitle)

            Picker(selection: $selection) {
                ForEach(event.options.enumerated(), id: \.offset) { index, option in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(option.label)
                        if let description = option.description, !description.isEmpty {
                            Text(description)
                                .font(.cardBody)
                                .foregroundStyle(.contentSecondary)
                        }
                    }
                    .padding(.leading, Spacing.xxs)
                    .tag(Optional(index))
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.radioGroup)
            .labelsHidden()
            .onChange(of: selection) { _, newValue in
                guard let index = newValue else { return }
                actions.onAskUserResponse?(event.id, index, nil)
            }

            Text("Or type a message to answer in your own words.")
                .font(.cardBody)
                .foregroundStyle(.contentTertiary)
        }
        .cardContainer()
        .transition(Motion.approvalAppear)
    }

    // MARK: - Answered (compact one-liner)

    private var isDismissed: Bool { event.customText == "Dismissed" }

    @ViewBuilder
    private var resolvedLabel: some View {
        let label = Label(resolvedText, systemImage: isDismissed ? "bubble" : "checkmark.bubble")
            .systemContainer()
            .frame(maxWidth: .infinity, alignment: .center)
            .transition(Motion.approvalAppear)

        if isDismissed {
            label.foregroundStyle(.contentSecondary)
        } else {
            label.foregroundStyle(.statusSuccess)
        }
    }

    private var resolvedText: String {
        if isDismissed {
            return "No answer, dismissed"
        }
        if event.selectedIndex == AskUserEvent.customTextIndex {
            return "Answered with a message"
        }
        return "Selected: \(event.selectedLabel ?? "Unknown")"
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
            status: .answered
        ))

        AskUserCard(event: AskUserEvent(
            id: "4",
            question: "Which format should I use for your notes?",
            options: [
                .init(label: "Markdown", description: nil),
                .init(label: "Plain Text", description: nil),
            ],
            selectedIndex: AskUserEvent.customTextIndex,
            customText: "Dismissed",
            status: .answered
        ))
    }
    .padding()
    .frame(width: 500)
    .background(.surfaceDefault)
}
