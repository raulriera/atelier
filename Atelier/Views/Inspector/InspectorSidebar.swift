import SwiftUI
import AtelierDesign
import AtelierKit

/// Routes inspector detail to the appropriate view based on the current selection.
struct InspectorSidebar: View {
    let selectedTool: ToolUseEvent?
    let selectedTaskCompletion: TaskCompletionEvent?

    var body: some View {
        if let event = selectedTool {
            ToolDetailView(event: event)
        } else if let event = selectedTaskCompletion {
            TaskRunDetailView(event: event)
        } else {
            ContentUnavailableView {
                Label("No Selection", systemImage: "sidebar.right")
            } description: {
                Text("Choose an item in the conversation to see more details")
            }
        }
    }
}

#Preview("Empty") {
    InspectorSidebar(selectedTool: nil, selectedTaskCompletion: nil)
        .frame(width: 320, height: 400)
}
