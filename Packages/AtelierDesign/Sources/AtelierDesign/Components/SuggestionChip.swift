import SwiftUI

/// A tappable chip that displays a suggestion prompt with an icon,
/// title, and subtitle.
///
/// Used in the empty conversation state to showcase what Atelier can do.
/// Each chip injects its associated prompt into the compose field on tap.
///
/// Usage:
/// ```swift
/// SuggestionChip(
///     iconSystemName: "doc.text",
///     title: "Draft a document",
///     subtitle: "Start a proposal, brief, or report"
/// ) {
///     draft = promptText
/// }
/// ```
public struct SuggestionChip: View {
    /// SF Symbol name for the leading icon.
    let iconSystemName: String
    /// Short title displayed on the chip.
    let title: String
    /// Brief teaser describing what the prompt does.
    let subtitle: String
    /// Action invoked when the chip is tapped.
    let action: () -> Void

    @State private var isHovered = false

    public init(
        iconSystemName: String,
        title: String,
        subtitle: String,
        action: @escaping () -> Void
    ) {
        self.iconSystemName = iconSystemName
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Image(systemName: iconSystemName)
                    .font(.body)
                    .foregroundStyle(.contentPrimary)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(title)
                        .font(.cardBody)
                        .foregroundStyle(.contentPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.contentTertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardContainer()
        }
        .buttonStyle(.plain)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(Motion.morph, value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    LazyVGrid(
        columns: [GridItem(.flexible()), GridItem(.flexible())],
        spacing: Spacing.sm
    ) {
        SuggestionChip(
            iconSystemName: "doc.text",
            title: "Draft a document",
            subtitle: "Start a proposal, brief, or report"
        ) {}
        SuggestionChip(
            iconSystemName: "calendar",
            title: "Plan my week",
            subtitle: "Organize tasks and priorities"
        ) {}
        SuggestionChip(
            iconSystemName: "lightbulb",
            title: "Brainstorm ideas",
            subtitle: "Generate creative options"
        ) {}
        SuggestionChip(
            iconSystemName: "envelope",
            title: "Draft an email",
            subtitle: "Compose a professional message"
        ) {}
    }
    .frame(maxWidth: 500)
    .padding()
}
