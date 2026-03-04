import SwiftUI
import AtelierDesign

/// Displays a track-changes view for document edits.
///
/// Shows the removed text with strikethrough on a muted red background
/// and the replacement text on a muted green background. Designed for
/// knowledge-work documents — no line numbers, no code formatting.
///
/// Used in `InspectorSidebar` when an Edit tool is selected, and
/// potentially inline in the timeline once M3 integration lands.
struct ChangePreview: View {
    let oldText: String
    let newText: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(oldText)
                .font(.conversationCode)
                .foregroundStyle(.contentTertiary)
                .strikethrough()
                .padding(Spacing.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.statusError.opacity(0.12))
                .clipShape(.rect(cornerRadius: Radii.sm, style: .continuous))

            Text(newText)
                .font(.conversationCode)
                .foregroundStyle(.contentPrimary)
                .padding(Spacing.xs)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.statusSuccess.opacity(0.12))
                .clipShape(.rect(cornerRadius: Radii.sm, style: .continuous))
        }
        .textSelection(.enabled)
    }
}
