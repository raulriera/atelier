import SwiftUI
import AtelierDesign
import AtelierKit

/// Shown when Claude is not installed on this Mac.
///
/// Guides the user to download Claude before they can use Atelier.
/// Matches the visual style of `FolderSelectionView` — centered, minimal,
/// approachable for non-developer audiences.
struct CLISetupView: View {
    var onResolved: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.xs) {
                Text("Almost there")
                    .font(.sectionTitle)
                    .foregroundStyle(.contentPrimary)

                Text("Atelier works alongside Claude, which needs\nto be installed separately on your Mac.")
                    .font(.cardBody)
                    .foregroundStyle(.contentSecondary)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)

            VStack(spacing: Spacing.xs) {
                Button("Download Claude") {
                    openURL(URL(string: "https://claude.ai/download")!)
                }
                .buttonStyle(.glass)

                Button("I've already installed it") {
                    if CLIEngine.isAvailable {
                        onResolved()
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.contentSecondary)
            }
        }
        .frame(width: Layout.folderPickerWidth, height: Layout.folderPickerHeight)
    }
}

#Preview("Setup Required") {
    CLISetupView(onResolved: {})
}
