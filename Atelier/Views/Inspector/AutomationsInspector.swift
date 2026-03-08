import SwiftUI
import AtelierDesign
import AtelierKit

/// Automations tab for the inspector sidebar.
///
/// Shows scheduled tasks as Shortcuts-style colored cards in a grid.
/// Tap a card to edit, right-click for pause/resume/run/delete.
struct AutomationsInspector: View {
    let scheduleStore: ScheduleStore
    let projectPath: String?

    @State private var showingForm = false
    @State private var editingTask: ScheduledTask?

    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: Spacing.sm)
    ]

    /// Tasks filtered to the current project.
    private var projectTasks: [ScheduledTask] {
        guard let path = projectPath else { return [] }
        return scheduleStore.tasks(forProjectPath: path)
    }

    var body: some View {
        Group {
            if projectTasks.isEmpty {
                emptyState
            } else {
                taskGrid
            }
        }
        .sheet(isPresented: $showingForm) {
            formSheet
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
            .buttonStyle(.glassProminent)
        }
    }

    // MARK: - Grid

    private var taskGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Spacing.sm) {
                ForEach(projectTasks) { task in
                    AutomationCard(
                        task: task,
                        onEdit: {
                            editingTask = task
                            showingForm = true
                        },
                        onTogglePause: { scheduleStore.togglePause(task.id) },
                        onRunNow: { Task { await scheduleStore.runNow(task.id) } },
                        onDelete: { scheduleStore.remove(task.id) }
                    )
                }

                // Add button as the last card
                Button {
                    editingTask = nil
                    showingForm = true
                } label: {
                    VStack(alignment: .leading) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundStyle(.contentTertiary)

                        Spacer()

                        Text("New")
                            .font(.cardBody)
                            .foregroundStyle(.contentTertiary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .aspectRatio(1, contentMode: .fit)
                    .cardContainer()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("New automation")
            }
            .padding(Spacing.md)
        }
    }

    @ViewBuilder
    private var formSheet: some View {
        if let path = projectPath {
            AutomationFormView(
                scheduleStore: scheduleStore,
                projectPath: path,
                existingTask: editingTask
            )
        }
    }
}

// MARK: - Card

/// A Shortcuts-style colored card for a scheduled task.
private struct AutomationCard: View {
    let task: ScheduledTask
    let onEdit: () -> Void
    let onTogglePause: () -> Void
    let onRunNow: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteConfirmation = false
    @State private var optionKeyHeld = false

    /// Resolves the stored color name to a SwiftUI color.
    private var cardColor: Color {
        (TaskColor(rawValue: task.colorName) ?? .blue).swiftUIColor
    }

    /// SF Symbol for the schedule type.
    private var scheduleIcon: String {
        switch task.schedule {
        case .manual: "play.circle"
        case .hourly: "clock"
        case .daily: "sun.horizon"
        case .weekdays: "briefcase"
        case .weekends: "cup.and.saucer"
        case .weekly: "calendar"
        case .monthly: "calendar.badge.clock"
        case .cron: "terminal"
        }
    }

    var body: some View {
        Button(action: onEdit) {
            VStack(alignment: .leading) {
                HStack(alignment: .top) {
                    Image(systemName: scheduleIcon)
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.9))

                    Spacer()

                    cardMenu
                }

                Spacer()

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(task.name)
                        .font(.cardBody)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if !task.description.isEmpty {
                        Text(task.description)
                            .font(.metadata)
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.sm)
            .aspectRatio(1, contentMode: .fit)
            .background(
                RoundedRectangle(cornerRadius: Radii.md, style: .continuous)
                    .fill(cardColor.gradient)
            )
            .opacity(task.isPaused ? 0.6 : 1)
        }
        .buttonStyle(.plain)
        .onAppear { optionKeyHeld = NSEvent.modifierFlags.contains(.option) }
        .onModifierKeysChanged { _, new in
            optionKeyHeld = new.contains(.option)
        }
        .confirmationDialog("Delete \"\(task.name)\"?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive, action: onDelete)
        } message: {
            Text("This automation will be permanently removed.")
        }
    }

    private var cardMenu: some View {
        Menu {
            Button(task.isPaused ? "Resume" : "Pause", action: onTogglePause)
            Button("Run Now", action: onRunNow)

            if optionKeyHeld {
                Divider()
                Button("Show Logs") {
                    NSWorkspace.shared.open(task.logURL)
                }
            }

            Divider()
            Button("Delete", role: .destructive) { showingDeleteConfirmation = true }
        } label: {
            Image(systemName: "ellipsis")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white.opacity(0.7))
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
