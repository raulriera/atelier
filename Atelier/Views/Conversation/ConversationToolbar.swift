import SwiftUI
import AtelierDesign
import AtelierKit

struct ConversationToolbar: ToolbarContent {
    let isStreaming: Bool
    @Binding var showingCapabilities: Bool
    @Binding var showingContextFiles: Bool
    @Binding var showInspector: Bool
    @Binding var selectedModel: ModelConfiguration
    @Bindable var capabilityStore: CapabilityStore
    let activeContextFiles: [ContextFile]
    let onNewConversation: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button {
                onNewConversation()
            } label: {
                Label("New Conversation", systemImage: "plus.message")
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
            .disabled(isStreaming)
        }
        ToolbarItem(placement: .automatic) {
            Button {
                showingCapabilities.toggle()
            } label: {
                Label("Capabilities", systemImage: "puzzlepiece.extension")
            }
            .help("Capabilities")
            .popover(isPresented: $showingCapabilities) {
                CapabilitiesCard(capabilityStore: capabilityStore)
                    .padding(Spacing.sm)
            }
        }
        ToolbarItem(placement: .automatic) {
            Button {
                showingContextFiles.toggle()
            } label: {
                Label("Context Files", systemImage: "doc.text")
            }
            .help("Context Files")
            .popover(isPresented: $showingContextFiles) {
                ContextFilesCard(files: activeContextFiles)
            }
        }
        ToolbarItem(placement: .automatic) {
            ModelPickerView(selection: $selectedModel)
        }
        ToolbarItem(placement: .automatic) {
            Button {
                showInspector.toggle()
            } label: {
                Label("Inspector", systemImage: "sidebar.right")
            }
            .help("Toggle Inspector")
        }
    }
}
