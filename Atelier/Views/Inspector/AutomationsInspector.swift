import SwiftUI
import AtelierDesign
import AtelierKit

/// Automations tab for the inspector sidebar.
///
/// Shows the list of scheduled tasks with controls to create, pause,
/// resume, and delete. Each row shows the task name, schedule, and
/// last run status.
struct AutomationsInspector: View {
    let scheduleStore: ScheduleStore
    let projectPath: String?

    @State private var showingForm = false
    @State private var editingTask: ScheduledTask?

    /// Tasks filtered to the current project.
    private var projectTasks: [ScheduledTask] {
        guard let path = projectPath else { return [] }
        return scheduleStore.tasks(forProjectPath: path)
    }

    var body: some View {
        VStack(spacing: 0) {
            if projectTasks.isEmpty {
                emptyState
            } else {
                taskList
            }
        }
        .sheet(isPresented: $showingForm) {
            if let path = projectPath {
                AutomationFormView(
                    scheduleStore: scheduleStore,
                    projectPath: path,
                    existingTask: editingTask
                )
            }
        }
        .onChange(of: showingForm) { _, isPresented in
            if !isPresented { editingTask = nil }
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: Spacing.md) {
            ContentUnavailableView {
                Label("No Automations", systemImage: "clock.arrow.trianglehead.2.counterclockwise.rotate.90")
            } description: {
                Text("Scheduled tasks will appear here")
            }

            Button("New Automation") {
                editingTask = nil
                showingForm = true
            }
            .buttonStyle(.glass)
        }
    }

    // MARK: - List

    private var taskList: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()

                Button {
                    editingTask = nil
                    showingForm = true
                } label: {
                    Label("New", systemImage: "plus")
                }
                .buttonStyle(.glass)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)

            List {
                ForEach(projectTasks) { task in
                    taskRow(task)
                }
            }
            .listStyle(.inset)
        }
    }

    private func taskRow(_ task: ScheduledTask) -> some View {
        Button {
            editingTask = task
            showingForm = true
        } label: {
            HStack(spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    HStack(spacing: Spacing.xs) {
                        Text(task.name)
                            .font(.cardBody)
                            .foregroundStyle(task.isPaused ? AnyShapeStyle(.contentTertiary) : AnyShapeStyle(.contentPrimary))
                            .lineLimit(1)

                        if task.isPaused {
                            Text("Paused")
                                .font(.metadata)
                                .foregroundStyle(.contentTertiary)
                        }
                    }

                    Text(task.schedule.displayName)
                        .font(.metadata)
                        .foregroundStyle(.contentSecondary)
                        .lineLimit(1)
                }

                Spacer()

                statusIndicator(for: task)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(task.isPaused ? "Resume" : "Pause") {
                scheduleStore.togglePause(task.id)
            }

            Button("Run Now") {
                Task { await scheduleStore.runNow(task.id) }
            }

            Divider()

            Button("Delete", role: .destructive) {
                scheduleStore.remove(task.id)
            }
        }
    }

    @ViewBuilder
    private func statusIndicator(for task: ScheduledTask) -> some View {
        if let succeeded = task.lastRunSucceeded {
            Image(systemName: succeeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(succeeded ? .green : .orange)
                .help(succeeded ? "Last run succeeded" : "Last run failed")
        }
    }
}

#Preview("With tasks") {
    AutomationsInspector(scheduleStore: .preview, projectPath: "/Users/demo/Projects/research")
        .frame(width: 320, height: 500)
}

#Preview("Empty") {
    AutomationsInspector(scheduleStore: ScheduleStore(), projectPath: "/tmp")
        .frame(width: 320, height: 500)
}
