import SwiftUI
import AtelierDesign
import AtelierKit

/// Displays context files discovered in the project hierarchy, grouped by directory.
///
/// Files are organized into sections by their parent directory, with `.atelier/` and
/// `.atelier/memory/` files rolled up under the project root. Memory files appear inside
/// a collapsible `DisclosureGroup`.
///
/// Shown inside a toolbar popover from ``ConversationToolbar``.
struct ContextFilesCard: View {
    let files: [ContextFile]

    var body: some View {
        if files.isEmpty {
            ContentUnavailableView {
                Label("No Context Files", systemImage: "doc.text")
            } description: {
                Text("Add a CLAUDE.md, COWORK.md, or .atelier/context.md to your project to provide context.")
            }
            .frame(width: 280)
            .fixedSize()
        } else {
            List {
                ForEach(groups) { group in
                    Section(group.displayName) {
                        ForEach(group.files) { file in
                            Label(file.filename, systemImage: "doc.text.fill")
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        if !group.memoryFiles.isEmpty {
                            DisclosureGroup {
                                ForEach(group.memoryFiles) { file in
                                    Label(file.filename, systemImage: "document.badge.gearshape.fill")
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            } label: {
                                Label(".atelier/memory", systemImage: "folder.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .listStyle(.inset)
            .frame(minWidth: 260, idealWidth: 300)
        }
    }

    // MARK: - Grouping

    /// Groups the flat file array by parent directory, preserving discovery order.
    ///
    /// Files inside `.atelier/` and `.atelier/memory/` are rolled up to the project
    /// root so they share a section with top-level files like `CLAUDE.md`. Memory
    /// files are separated into ``DirectoryGroup/memoryFiles`` for the `DisclosureGroup`.
    private var groups: [DirectoryGroup] {
        var groupsByDirectory: [URL: DirectoryGroup] = [:]
        var order: [URL] = []

        for file in files {
            let directory: URL
            let parent = file.url.deletingLastPathComponent()
            if file.source == .memory {
                // .atelier/memory/foo.md → project root (two levels up from file)
                directory = parent.deletingLastPathComponent().deletingLastPathComponent()
            } else if parent.lastPathComponent == ".atelier" {
                // .atelier/context.md → project root (one level up)
                directory = parent.deletingLastPathComponent()
            } else {
                directory = parent
            }

            if groupsByDirectory[directory] == nil {
                groupsByDirectory[directory] = DirectoryGroup(directory: directory)
                order.append(directory)
            }

            if file.source == .memory {
                groupsByDirectory[directory]!.memoryFiles.append(file)
            } else {
                groupsByDirectory[directory]!.files.append(file)
            }
        }

        return order.compactMap { groupsByDirectory[$0] }
    }
}

/// Groups context files belonging to the same project directory.
///
/// Regular files (CLI-loaded and injected) go in ``files``, while memory
/// files go in ``memoryFiles`` for the nested `DisclosureGroup`.
private struct DirectoryGroup: Identifiable {
    let directory: URL
    var files: [ContextFile] = []
    var memoryFiles: [ContextFile] = []

    var id: URL { directory }

    /// Abbreviated directory path with `~` for the home directory prefix.
    var displayName: String { directory.abbreviatedPath }
}

// MARK: - Previews

#Preview("Context Files") {
    let projectRoot = URL(filePath: "/Users/raul/Developer/atelier")
    ContextFilesCard(files: [
        ContextFile(
            url: projectRoot.appending(path: "CLAUDE.md"),
            filename: "CLAUDE.md",
            source: .nativeCLI
        ),
        ContextFile(
            url: projectRoot.appending(path: "COWORK.md"),
            filename: "COWORK.md",
            source: .injected
        ),
        ContextFile(
            url: projectRoot.appending(path: ".atelier/context.md"),
            filename: "context.md",
            source: .injected
        ),
        ContextFile(
            url: projectRoot.appending(path: ".atelier/memory/MEMORY.md"),
            filename: "MEMORY.md",
            source: .memory
        ),
        ContextFile(
            url: projectRoot.appending(path: ".atelier/memory/patterns.md"),
            filename: "patterns.md",
            source: .memory
        ),
    ])
    .frame(height: 300)
}

#Preview("Empty State") {
    ContextFilesCard(files: [])
}
