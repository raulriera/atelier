import SwiftUI
import AtelierDesign
import AtelierKit

/// A persistent task card pinned above the compose field.
///
/// Stays visible regardless of scroll position and updates in-place as tasks
/// progress. The user can dismiss it; new tasks after dismissal bring it back.
struct TaskListOverlay: View {
    let session: Session
    @State private var isDismissed = false

    private var isVisible: Bool {
        !session.taskEntries.isEmpty && !isDismissed
    }

    var body: some View {
        let entries = session.taskEntries

        if isVisible {
            TaskCard(
                entries: entries,
                onDismiss: {
                    withAnimation(Motion.settle) {
                        isDismissed = true
                    }
                }
            )
            .frame(maxWidth: Layout.readingWidth)
            .padding(.horizontal, Spacing.md)
            .transition(Motion.cardReveal)
            .onChange(of: entries.count) { old, new in
                if new > old {
                    withAnimation(Motion.appear) {
                        isDismissed = false
                    }
                }
            }
        }
    }
}

// MARK: - Previews

@MainActor
private func previewSession(step: Int) -> Session {
    let session = Session()
    session.beginAssistantMessage()
    TaskPreviewFixtures.populateSession(session, step: step)
    return session
}

#Preview("All pending") {
    TaskListOverlay(session: previewSession(step: 1))
        .padding()
        .frame(width: 500)
        .background(.surfaceDefault)
}

#Preview("One in progress") {
    TaskListOverlay(session: previewSession(step: 2))
        .padding()
        .frame(width: 500)
        .background(.surfaceDefault)
}

#Preview("Two done, one active") {
    TaskListOverlay(session: previewSession(step: 3))
        .padding()
        .frame(width: 500)
        .background(.surfaceDefault)
}

#Preview("All completed — dismissible") {
    TaskListOverlay(session: previewSession(step: 4))
        .padding()
        .frame(width: 500)
        .background(.surfaceDefault)
}

#Preview("Partially cancelled") {
    TaskListOverlay(session: previewSession(step: 5))
        .padding()
        .frame(width: 500)
        .background(.surfaceDefault)
}
