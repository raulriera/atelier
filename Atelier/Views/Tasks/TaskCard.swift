import SwiftUI
import AtelierDesign
import AtelierKit

/// A prominent floating card showing all tasks as a checklist.
///
/// Uses Liquid Glass to match macOS system chrome and stand out as the most
/// valuable persistent element on screen. Larger typography and generous
/// spacing give it visual weight above the compose field.
struct TaskCard: View {
    let entries: [TaskEntry]
    var onDismiss: (() -> Void)?

    private var isDismissable: Bool {
        !entries.contains { $0.isActive }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            // Header
            HStack {
                Text("Tasks")
                    .font(.cardTitle)
                    .foregroundStyle(.contentPrimary)

                Spacer()

                if let onDismiss, isDismissable {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .symbolRenderingMode(.hierarchical)
                            .foregroundStyle(.contentSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss tasks")
                    .transition(.opacity)
                }
            }

            // Task rows
            ForEach(entries) { entry in
                TaskEntryRow(entry: entry)
            }
        }
        .padding(Spacing.md)
        .glassEffect(.regular, in: .rect(cornerRadius: Radii.lg, style: .continuous))
        .transition(Motion.cardReveal)
    }
}

// MARK: - Task Entry Row

private struct TaskEntryRow: View {
    let entry: TaskEntry

    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: entry.iconName)
                .symbolEffect(.rotate, options: .repeating, isActive: entry.isAnimating)
                .font(.body)
                .foregroundStyle(iconStyle)
                .frame(width: 20)

            Text(entry.subject)
                .font(.conversationBody)
                .foregroundStyle(textStyle)
                .lineLimit(2)
                .truncationMode(.tail)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.subject), \(entry.status.accessibilityDescription)")
    }

    private var iconStyle: AnyShapeStyle {
        switch entry.status {
        case .completed, .inProgress: AnyShapeStyle(.contentAccent)
        case .cancelled, .pending, .deleted: AnyShapeStyle(.contentTertiary)
        }
    }

    private var textStyle: AnyShapeStyle {
        switch entry.status {
        case .completed: AnyShapeStyle(.contentSecondary)
        case .inProgress: AnyShapeStyle(.contentPrimary)
        case .cancelled: AnyShapeStyle(.contentTertiary)
        case .pending, .deleted: AnyShapeStyle(.contentSecondary)
        }
    }
}

// MARK: - Previews

#Preview("All pending") {
    TaskCard(entries: TaskPreviewFixtures.entries(step: 1), onDismiss: {})
        .padding()
        .frame(width: 500)
        .background(.surfaceDefault)
}

#Preview("One in progress") {
    TaskCard(entries: TaskPreviewFixtures.entries(step: 2), onDismiss: {})
        .padding()
        .frame(width: 500)
        .background(.surfaceDefault)
}

#Preview("One done, one active") {
    TaskCard(entries: TaskPreviewFixtures.entries(step: 3), onDismiss: {})
        .padding()
        .frame(width: 500)
        .background(.surfaceDefault)
}

#Preview("All completed") {
    TaskCard(entries: TaskPreviewFixtures.entries(step: 4), onDismiss: {})
        .padding()
        .frame(width: 500)
        .background(.surfaceDefault)
}

#Preview("Partially cancelled") {
    TaskCard(entries: TaskPreviewFixtures.entries(step: 5), onDismiss: {})
        .padding()
        .frame(width: 500)
        .background(.surfaceDefault)
}
