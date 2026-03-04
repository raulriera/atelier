import SwiftUI
import AtelierDesign
import AtelierSecurity

struct FolderAccessRow: View {
    let entry: BookmarkEntry
    let onRevoke: () -> Void

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "folder.fill")
                .foregroundStyle(.contentAccent)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(entry.url.lastPathComponent)
                    .font(.cardTitle)
                    .foregroundStyle(.contentPrimary)
                    .lineLimit(1)

                Text(abbreviatedPath)
                    .font(.metadata)
                    .foregroundStyle(.contentSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Button {
                onRevoke()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.contentTertiary)
            }
            .buttonStyle(.plain)
            .help("Revoke access")
        }
        .padding(.vertical, Spacing.xxs)
    }

    private var abbreviatedPath: String {
        let path = entry.url.path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}
