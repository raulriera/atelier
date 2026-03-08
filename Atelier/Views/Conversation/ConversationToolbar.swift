import SwiftUI
import AtelierDesign
import AtelierKit

/// Toolbar with inspector tab icons.
struct ConversationToolbar: ToolbarContent {
    @Binding var showInspector: Bool
    @Binding var inspectorTab: InspectorTab

    var body: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            HStack(spacing: 0) {
                ForEach(InspectorTab.allCases) { tab in
                    Button {
                        if inspectorTab == tab && showInspector {
                            showInspector = false
                        } else {
                            inspectorTab = tab
                            showInspector = true
                        }
                    } label: {
                        Image(systemName: tab.systemImage)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.accessoryBar)
                    .opacity(inspectorTab == tab && showInspector ? 1 : 0.5)
                    .accessibilityAddTraits(inspectorTab == tab && showInspector ? .isSelected : [])
                    .help(tab.label)
                }
            }
        }
    }
}
