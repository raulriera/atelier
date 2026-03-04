import SwiftUI
import AtelierDesign

struct FolderSelectionView: View {
    var onSelect: (URL) -> Void

    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.contentSecondary)

            Text("Drop a folder to start")
                .font(.sectionTitle)
                .foregroundStyle(.contentPrimary)

            Button("Choose Folder...") {
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: Radii.lg, style: .continuous)
                .strokeBorder(.contentTertiary.opacity(isTargeted ? 1 : 0), lineWidth: 2)
                .animation(Motion.morph, value: isTargeted)
        }
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
