import SwiftUI
import AtelierDesign
import AtelierKit

/// Always-open inspector sidebar with three sections:
/// capabilities, automations (scheduled tasks), and tool detail.
struct InspectorPanel: View {
    @Binding var selectedTab: InspectorTab
    @Bindable var capabilityStore: CapabilityStore
    let scheduleStore: ScheduleStore
    let projectPath: String?
    let projectId: UUID
    let selectedTool: ToolUseEvent?

    var body: some View {
        tabContent
    }

    // MARK: - Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .capabilities:
            CapabilitiesInspector(capabilityStore: capabilityStore)
        case .automations:
            AutomationsInspector(scheduleStore: scheduleStore, capabilityStore: capabilityStore, projectPath: projectPath, projectId: projectId)
        case .detail:
            InspectorSidebar(selectedTool: selectedTool)
        }
    }
}

#Preview {
    InspectorPanel(
        selectedTab: .constant(.capabilities),
        capabilityStore: .preview,
        scheduleStore: .preview,
        projectPath: "/Users/demo/Projects/research",
        projectId: UUID(),
        selectedTool: nil
    )
    .frame(width: 320, height: 600)
}
