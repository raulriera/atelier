import SwiftUI
import AtelierDesign
import AtelierKit

/// The empty conversation state showing a welcome header and a grid
/// of suggestion chips that showcase what Atelier can do.
///
/// Tapping a suggestion injects its prompt text into the compose field.
/// Suggestions are shuffled fresh each time the view appears.
struct WelcomeView: View {
    /// Binding to the compose field draft text.
    @Binding var draft: String
    /// Currently enabled capability IDs for filtering suggestions.
    var enabledCapabilityIDs: Set<String> = []

    @State private var suggestions: [SuggestionPrompt] = []

    var body: some View {
        VStack(spacing: Spacing.md) {
            ContentUnavailableView {
                Label("Let's work on something great!", systemImage: "sparkles")
            }

            // Suggestion grid inside a single glass sheet.
            GlassEffectContainer(spacing: 0) {
                VStack(spacing: 0) {
                    ForEach(0..<(suggestions.count + 1) / 2, id: \.self) { row in
                        if row > 0 {
                            Divider()
                        }
                        HStack(spacing: 0) {
                            ForEach(0..<2, id: \.self) { col in
                                let index = row * 2 + col
                                if col > 0 {
                                    Divider()
                                }
                                if index < suggestions.count {
                                    let suggestion = suggestions[index]
                                    SuggestionChip(
                                        iconSystemName: suggestion.iconSystemName,
                                        title: suggestion.title,
                                        subtitle: suggestion.subtitle
                                    ) {
                                        draft = suggestion.prompt
                                    }
                                    .transition(Motion.cardReveal)
                                    .animation(
                                        Motion.appear.delay(Double(index) * 0.05),
                                        value: suggestions.count
                                    )
                                }
                            }
                        }
                    }
                }
                .glassEffect(.regular, in: .rect(cornerRadius: Radii.md, style: .continuous))
            }
            .frame(maxWidth: 500)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, Spacing.lg)
        .onAppear {
            guard suggestions.isEmpty else { return }
            suggestions = SuggestionProvider.suggestions(enabledCapabilityIDs: enabledCapabilityIDs)
        }
    }
}

#Preview {
    @Previewable @State var draft = ""
    WelcomeView(draft: $draft)
}
