import SwiftUI
import AtelierDesign
import AtelierKit
import AtelierSecurity
import UniformTypeIdentifiers

struct FolderAccessCard: View {
    @Bindable var fileAccessStore: FileAccessStore
    @State private var isDropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            header
            errorBanner
            content
        }
        .cardContainer()
        .frame(width: 280)
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers)
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: Radii.md, style: .continuous)
                    .stroke(.contentAccent, lineWidth: 2)
            }
        }
        .animation(Motion.settle, value: isDropTargeted)
    }

    private var header: some View {
        HStack {
            Text("Folder Access")
                .font(.cardTitle)
                .foregroundStyle(.contentPrimary)

            Spacer()

            Button("Add Folder") {
                Task {
                    if let url = await FolderPicker.chooseFolder() {
                        await fileAccessStore.grant(url: url)
                    }
                }
            }
            .buttonStyle(.inline)
        }
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let error = fileAccessStore.error {
            HStack(spacing: Spacing.xs) {
                Text(error.localizedMessage)
                    .font(.metadata)
                    .foregroundStyle(.statusError)

                Spacer()

                Button {
                    fileAccessStore.dismissError()
                } label: {
                    Image(systemName: "xmark")
                        .font(.metadata)
                        .foregroundStyle(.contentSecondary)
                }
                .buttonStyle(.plain)
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var content: some View {
        if fileAccessStore.entries.isEmpty {
            emptyState
        } else {
            folderList
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.xs) {
            Image(systemName: "folder.badge.plus")
                .font(.title2)
                .foregroundStyle(.contentTertiary)

            Text("Drop a folder here or click Add Folder")
                .font(.metadata)
                .foregroundStyle(.contentTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
    }

    private var folderList: some View {
        VStack(spacing: 0) {
            ForEach(fileAccessStore.entries) { entry in
                FolderAccessRow(entry: entry) {
                    Task {
                        await fileAccessStore.revoke(url: entry.url)
                    }
                }
            }
        }
        .animation(Motion.settle, value: fileAccessStore.entries.count)
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { data, _ in
                guard let data = data as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil),
                      url.hasDirectoryPath || (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
                else { return }

                Task { @MainActor in
                    await fileAccessStore.grant(url: url)
                }
            }
        }
        return true
    }
}
