import SwiftUI
import AtelierKit

/// Debug-only panel showing the health of a project's living context system.
///
/// Displays memory file sizes, token estimates, compaction snapshot state,
/// and the full injection preview. Hidden behind a menu bar icon for
/// developer testing.
struct ContextHealthView: View {
    let projectStore: ProjectStore

    @State private var selectedProjectID: UUID?
    @State private var health: ContextHealth?
    @State private var injectionPreview: String?

    private var projects: [ProjectMetadata] {
        projectStore.allProjects().filter { $0.rootURL != nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if let health {
                ScrollView {
                    content(health)
                        .padding()
                }
            } else {
                ContentUnavailableView(
                    "No Project Selected",
                    systemImage: "folder.badge.questionmark",
                    description: Text("Pick a project above to inspect its context health.")
                )
            }
        }
        .frame(width: 480, height: 600)
        .onChange(of: selectedProjectID) { _, newValue in
            refresh(projectID: newValue)
        }
        .onAppear {
            if selectedProjectID == nil {
                selectedProjectID = projects.first?.id
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Picker("Project", selection: $selectedProjectID) {
                ForEach(projects) { project in
                    Text(project.displayName)
                        .tag(Optional(project.id))
                }
            }
            .labelsHidden()

            Spacer()

            Button {
                refresh(projectID: selectedProjectID)
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh")
        }
        .padding()
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ health: ContextHealth) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            summarySection(health)
            Divider()
            filesSection(health)
            if health.compactionSnapshotCount > 0 {
                Divider()
                compactionSection(health)
            }
            if let preview = injectionPreview {
                Divider()
                injectionSection(preview)
            }
        }
    }

    // MARK: - Summary

    private func summarySection(_ health: ContextHealth) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Summary")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 4) {
                GridRow {
                    Text("Always injected")
                        .foregroundStyle(.secondary)
                    Text("\(formatted(health.alwaysInjectedBytes)) (\(health.alwaysInjectedTokens) tokens)")
                        .monospacedDigit()
                }
                GridRow {
                    Text("Total on disk")
                        .foregroundStyle(.secondary)
                    Text("\(formatted(health.totalBytes)) (\(health.totalTokens) tokens)")
                        .monospacedDigit()
                }
                GridRow {
                    Text("Compaction snapshots")
                        .foregroundStyle(.secondary)
                    Text("\(health.compactionSnapshotCount)")
                        .monospacedDigit()
                }
                if let date = health.latestCompactionDate {
                    GridRow {
                        Text("Last compaction")
                            .foregroundStyle(.secondary)
                        Text(date, style: .relative) + Text(" ago")
                    }
                }
            }
            .font(.callout)
        }
    }

    // MARK: - Files

    private func filesSection(_ health: ContextHealth) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Context Files")
                .font(.headline)

            ForEach(health.files) { file in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(file.filename)
                            .font(.callout.monospaced())
                        Text(file.source.rawValue)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(file.lineCount) lines")
                            .font(.callout)
                            .monospacedDigit()
                        Text("\(file.estimatedTokens) tokens")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }

                    budgetIndicator(for: file)
                        .frame(width: 8)
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private func budgetIndicator(for file: ContextHealth.FileEntry) -> some View {
        let budget = fileBudget(for: file.filename)
        if let budget {
            let ratio = Double(file.lineCount) / Double(budget)
            Circle()
                .fill(ratio > 0.9 ? .red : ratio > 0.7 ? .orange : .green)
                .frame(width: 8, height: 8)
                .help("\(file.lineCount)/\(budget) lines")
        }
    }

    private func fileBudget(for filename: String) -> Int? {
        switch filename {
        case "preferences.md": 25
        case "corrections.md": 15
        case "decisions.md": 30
        case "patterns.md": 25
        default: nil
        }
    }

    // MARK: - Compaction

    private func compactionSection(_ health: ContextHealth) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Compaction Snapshots")
                .font(.headline)

            let snapshots = health.files.filter { $0.source == .compactionSnapshot }
            ForEach(snapshots) { snapshot in
                HStack {
                    Text(snapshot.filename)
                        .font(.callout.monospaced())
                    Spacer()
                    Text(formatted(snapshot.byteSize))
                        .font(.callout)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Injection Preview

    private func injectionSection(_ preview: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Injection Preview")
                    .font(.headline)
                Spacer()
                Text("\(preview.count) chars")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                Text(preview)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .padding(8)
            }
            .frame(maxHeight: 200)
            .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
        }
    }

    // MARK: - Helpers

    private func refresh(projectID: UUID?) {
        guard let id = projectID,
              let metadata = projectStore.project(for: id),
              let rootURL = metadata.rootURL
        else {
            health = nil
            injectionPreview = nil
            return
        }

        health = ContextHealth.scan(projectRoot: rootURL)

        let contextFiles = ContextFileLoader.discover(from: rootURL)
        injectionPreview = ContextFileLoader.contentForInjection(from: contextFiles)
    }

    private func formatted(_ bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}

#Preview {
    ContextHealthView(
        projectStore: ProjectStore(
            baseDirectory: FileManager.default.temporaryDirectory
        )
    )
}
