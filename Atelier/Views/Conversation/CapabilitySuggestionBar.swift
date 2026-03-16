import SwiftUI
import AtelierDesign
import AtelierKit

/// Inline bar that appears below an assistant message when Claude mentions
/// a disabled capability, offering one-tap enable buttons.
struct CapabilitySuggestionBar: View {
    let capabilities: [Capability]

    @Environment(\.timelineActions) private var actions

    var body: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(capabilities) { cap in
                Button {
                    actions.onEnableCapability?(cap.id)
                } label: {
                    Label("Enable \(cap.name)", systemImage: cap.iconSystemName)
                }
                .buttonStyle(.glass)
                .controlSize(.regular)
            }
        }
        .padding(.leading, Spacing.xs)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Spacing.md) {
        CapabilitySuggestionBar(capabilities: [
            Capability(
                id: "calendar",
                name: "Calendar",
                description: "View and create events",
                iconSystemName: "calendar",
                serverConfig: MCPServerConfig(command: "/usr/bin/true", serverName: "calendar")
            ),
        ])

        CapabilitySuggestionBar(capabilities: [
            Capability(
                id: "mail",
                name: "Mail",
                description: "Read and send email",
                iconSystemName: "envelope",
                serverConfig: MCPServerConfig(command: "/usr/bin/true", serverName: "mail")
            ),
            Capability(
                id: "notes",
                name: "Notes",
                description: "Read and create notes",
                iconSystemName: "note.text",
                serverConfig: MCPServerConfig(command: "/usr/bin/true", serverName: "notes")
            ),
        ])
    }
    .padding()
    .background(.surfaceDefault)
}
