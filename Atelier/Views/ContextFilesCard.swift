import SwiftUI
import AtelierDesign
import AtelierKit

struct ContextFilesCard: View {
    let files: [ContextFile]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            header
            content
        }
        .cardContainer()
        .frame(width: 280)
    }

    private var header: some View {
        Text("Context Files")
            .font(.cardTitle)
            .foregroundStyle(.contentPrimary)
    }

    @ViewBuilder
    private var content: some View {
        if files.isEmpty {
            emptyState
        } else {
            fileList
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: "doc.text")
                .font(.title2)
                .foregroundStyle(.contentTertiary)

            Text("Add a CLAUDE.md, COWORK.md, or .atelier/context.md to your project to provide context.")
                .font(.metadata)
                .foregroundStyle(.contentTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
    }

    private var fileList: some View {
        VStack(spacing: 0) {
            ForEach(files) { file in
                ContextFileRow(file: file)
            }
        }
    }
}

private struct ContextFileRow: View {
    let file: ContextFile

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "doc.text.fill")
                .foregroundStyle(.contentAccent)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(file.filename)
                    .font(.cardTitle)
                    .foregroundStyle(.contentPrimary)
                    .lineLimit(1)

                Text(abbreviatedDirectory)
                    .font(.metadata)
                    .foregroundStyle(.contentSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if file.source == .atelierInjected {
                Text("Injected")
                    .font(.metadata)
                    .foregroundStyle(.contentAccent)
            }
        }
        .padding(.vertical, Spacing.xxs)
    }

    private var abbreviatedDirectory: String {
        let dir = file.url.deletingLastPathComponent().path
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if dir.hasPrefix(home) {
            return "~" + dir.dropFirst(home.count)
        }
        return dir
    }
}
