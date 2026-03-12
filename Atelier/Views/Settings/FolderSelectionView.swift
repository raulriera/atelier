import SwiftUI
import AtelierDesign

/// Shown when a project has no folder assigned yet.
///
/// The user can drag a folder onto the view or pick one with the file dialog.
struct FolderSelectionView: View {
    var onSelect: (URL) -> Void

    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.contentSecondary)
                .accessibilityHidden(true)

            VStack(spacing: Spacing.xs) {
                Text("Open a project")
                    .font(.sectionTitle)
                    .foregroundStyle(.contentPrimary)

                Text("Drag a folder here, or choose one from your Mac.")
                    .font(.cardBody)
                    .foregroundStyle(.contentSecondary)
                    .multilineTextAlignment(.center)
            }
            .accessibilityElement(children: .combine)

            Button("Choose Folder…") {
                Task {
                    guard let url = await FolderPicker.chooseFolder(
                        message: "Choose a folder to open as a project",
                        prompt: "Open"
                    ) else { return }
                    onSelect(url)
                }
            }
            .buttonStyle(.glass)
        }
        .frame(width: Layout.folderPickerWidth, height: Layout.folderPickerHeight)
        .contentShape(.rect)
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
                  isDir.boolValue else { return false }
            onSelect(url)
            return true
        } isTargeted: { targeted in
            isTargeted = targeted
        }
    }
}

#Preview("Folder Selection") {
    FolderSelectionView(onSelect: { _ in })
}
