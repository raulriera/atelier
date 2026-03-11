import SwiftUI
import AtelierDesign
import AtelierKit

/// Form for creating or editing a scheduled task.
///
/// Presented as a sheet from the automations inspector. Fields map
/// directly to `ScheduledTask` properties. The schedule picker
/// reveals time/day controls based on the selected frequency.
struct AutomationFormView: View {
    @Environment(\.dismiss) private var dismiss

    let scheduleStore: ScheduleStore
    let projectPath: String
    let projectId: UUID

    /// When editing an existing task, this is set. `nil` for create.
    let existingTask: ScheduledTask?

    @State private var name = ""
    @State private var description = ""
    @State private var prompt = ""
    @State private var scheduleType: ScheduleType = .daily
    @State private var hour = 9
    @State private var minute = 0
    @State private var weekday = 1
    @State private var monthDay = 1
    @State private var selectedModel: String?
    @State private var selectedColor: TaskColor = .blue

    init(scheduleStore: ScheduleStore, projectPath: String, projectId: UUID, existingTask: ScheduledTask? = nil) {
        self.scheduleStore = scheduleStore
        self.projectPath = projectPath
        self.projectId = projectId
        self.existingTask = existingTask

        if let task = existingTask {
            _name = State(initialValue: task.name)
            _description = State(initialValue: task.description)
            _prompt = State(initialValue: task.prompt)
            _selectedModel = State(initialValue: task.model)

            if let preset = TaskColor(rawValue: task.colorName) {
                _selectedColor = State(initialValue: preset)
            }

            switch task.schedule {
            case .manual:
                _scheduleType = State(initialValue: .manual)
            case .hourly:
                _scheduleType = State(initialValue: .hourly)
            case .daily(let h, let m):
                _scheduleType = State(initialValue: .daily)
                _hour = State(initialValue: h)
                _minute = State(initialValue: m)
            case .weekdays(let h, let m):
                _scheduleType = State(initialValue: .weekdays)
                _hour = State(initialValue: h)
                _minute = State(initialValue: m)
            case .weekends(let h, let m):
                _scheduleType = State(initialValue: .weekends)
                _hour = State(initialValue: h)
                _minute = State(initialValue: m)
            case .weekly(let w, let h, let m):
                _scheduleType = State(initialValue: .weekly)
                _weekday = State(initialValue: w)
                _hour = State(initialValue: h)
                _minute = State(initialValue: m)
            case .monthly(let d, let h, let m):
                _scheduleType = State(initialValue: .monthly)
                _monthDay = State(initialValue: d)
                _hour = State(initialValue: h)
                _minute = State(initialValue: m)
            case .cron:
                _scheduleType = State(initialValue: .daily)
            }
        }
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
        && !prompt.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Form {
                    Section("Task") {
                        TextField("Name", text: $name, prompt: Text("Morning briefing"))
                        TextField("Description", text: $description, prompt: Text("Optional"))
                    }
                }
                .formStyle(.grouped)
                .scrollDisabled(true)
                .fixedSize(horizontal: false, vertical: true)

                // Prompt lives outside the Form so it has no section container
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Prompt")
                        .font(.system(.subheadline))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    PromptField(text: $prompt)
                }
                .padding(.horizontal, 20) // Matches .formStyle(.grouped) section inset
                .padding(.vertical, Spacing.xs)

                Form {
                    Section("Schedule") {
                        Picker("Frequency", selection: $scheduleType) {
                            ForEach(ScheduleType.allCases) { type in
                                Text(type.label).tag(type)
                            }
                        }

                        if scheduleType.showsTime {
                            HStack {
                                Picker("Hour", selection: $hour) {
                                    ForEach(0..<24, id: \.self) { h in
                                        Text(String(format: "%d %@", h % 12 == 0 ? 12 : h % 12, h >= 12 ? "PM" : "AM"))
                                            .tag(h)
                                    }
                                }

                                Picker("Minute", selection: $minute) {
                                    ForEach([0, 15, 30, 45], id: \.self) { m in
                                        Text(String(format: ":%02d", m)).tag(m)
                                    }
                                }
                            }
                        }

                        if scheduleType == .weekly {
                            Picker("Day", selection: $weekday) {
                                Text("Sunday").tag(0)
                                Text("Monday").tag(1)
                                Text("Tuesday").tag(2)
                                Text("Wednesday").tag(3)
                                Text("Thursday").tag(4)
                                Text("Friday").tag(5)
                                Text("Saturday").tag(6)
                            }
                        }

                        if scheduleType == .monthly {
                            Picker("Day of month", selection: $monthDay) {
                                ForEach(1...28, id: \.self) { d in
                                    Text("\(d)").tag(d)
                                }
                            }
                        }
                    }

                    Section("Model") {
                        Picker("Model", selection: $selectedModel) {
                            Text("Default").tag(nil as String?)
                            ForEach(ModelConfiguration.allModels) { model in
                                Text(model.displayName).tag(model.cliAlias as String?)
                            }
                        }
                    }

                    Section("Color") {
                        colorPicker
                    }
                }
                .formStyle(.grouped)
                .scrollDisabled(true)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(minWidth: 360, idealWidth: 420, minHeight: 400, idealHeight: 500)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(existingTask == nil ? "Create" : "Save") {
                    save()
                    dismiss()
                }
                .disabled(!isValid)
            }
        }
    }

    // MARK: - Color Picker

    private var colorPicker: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(TaskColor.allCases) { color in
                Button {
                    selectedColor = color
                } label: {
                    Circle()
                        .fill(color.swiftUIColor.gradient)
                        .frame(width: 24, height: 24)
                        .overlay {
                            if selectedColor == color {
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(color.rawValue.capitalized)
                .accessibilityAddTraits(selectedColor == color ? .isSelected : [])
            }
        }
    }

    // MARK: - Save

    private func save() {
        let schedule = buildSchedule()
        let colorValue = selectedColor.rawValue

        if var task = existingTask {
            task.name = name.trimmingCharacters(in: .whitespaces)
            task.description = description.trimmingCharacters(in: .whitespaces)
            task.prompt = prompt.trimmingCharacters(in: .whitespaces)
            task.schedule = schedule
            task.model = selectedModel
            task.colorName = colorValue
            scheduleStore.update(task)
        } else {
            let task = ScheduledTask(
                name: name.trimmingCharacters(in: .whitespaces),
                description: description.trimmingCharacters(in: .whitespaces),
                prompt: prompt.trimmingCharacters(in: .whitespaces),
                schedule: schedule,
                model: selectedModel,
                projectPath: projectPath,
                projectId: projectId,
                colorName: colorValue
            )
            scheduleStore.add(task)
        }
    }

    private func buildSchedule() -> TaskSchedule {
        switch scheduleType {
        case .manual: .manual
        case .hourly: .hourly
        case .daily: .daily(hour: hour, minute: minute)
        case .weekdays: .weekdays(hour: hour, minute: minute)
        case .weekends: .weekends(hour: hour, minute: minute)
        case .weekly: .weekly(weekday: weekday, hour: hour, minute: minute)
        case .monthly: .monthly(day: monthDay, hour: hour, minute: minute)
        }
    }
}

// MARK: - Schedule Type

/// Simplified schedule picker cases for the form UI.
private enum ScheduleType: String, CaseIterable, Identifiable {
    case manual, hourly, daily, weekdays, weekends, weekly, monthly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .manual: "Manual"
        case .hourly: "Every hour"
        case .daily: "Daily"
        case .weekdays: "Weekdays"
        case .weekends: "Weekends"
        case .weekly: "Weekly"
        case .monthly: "Monthly"
        }
    }

    var showsTime: Bool {
        switch self {
        case .manual, .hourly: false
        case .daily, .weekdays, .weekends, .weekly, .monthly: true
        }
    }
}

// MARK: - Prompt Field

/// Text editor with the shared glowing field treatment, no submit button.
private struct PromptField: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .focused($isFocused)
                .font(.conversationBody)
                .foregroundStyle(.contentPrimary)
                .textEditorStyle(.plain)
                .scrollContentBackground(.hidden)
                .contentMargins(.all, 0, for: .scrollContent)
                .scrollIndicators(.hidden)
                .frame(minHeight: 80, maxHeight: 200)
                .fixedSize(horizontal: false, vertical: true)
                .offset(y: -2)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .glowingFieldContainer(isFocused: isFocused)
    }
}

#Preview {
    AutomationFormView(scheduleStore: .preview, projectPath: "/tmp/project", projectId: UUID())
}
