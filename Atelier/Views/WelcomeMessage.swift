import SwiftUI
import AtelierDesign

struct WelcomeMessage: View {
    var body: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(.contentAccent)
                .padding(.bottom, Spacing.xxs)

            Text("Welcome to Atelier")
                .font(.sectionTitle)
                .foregroundStyle(.contentPrimary)

            Text("Start a conversation with Claude.")
                .font(.cardBody)
                .foregroundStyle(.contentTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.lg)
    }
}
