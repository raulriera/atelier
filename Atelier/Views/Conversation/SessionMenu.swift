import SwiftUI
import AtelierDesign
import AtelierKit

/// Toolbar item that shows a chromeless chevron next to the navigation title.
///
/// Tapping the chevron presents a popover with the session list.
/// Uses `.sharedBackgroundVisibility(.hidden)` to opt out of the automatic
/// Liquid Glass background that macOS 26 applies to toolbar items.
struct SessionMenuToolbarItem: ToolbarContent {
    let projectName: String
    @Binding var showMenu: Bool
    let sessions: [SessionSnapshotMetadata]
    let currentSessionId: String?
    let onSelect: (String) -> Void
    let onNewConversation: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button {
                showMenu.toggle()
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xxs ) {
                    Text(projectName)
                        .font(.sectionTitle)
                        .fontWeight(.semibold)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showMenu) {
                SessionMenu(
                    sessions: sessions,
                    currentSessionId: currentSessionId,
                    onSelect: {
                        showMenu = false
                        onSelect($0)
                    },
                    onNewConversation: {
                        showMenu = false
                        onNewConversation()
                    }
                )
            }
        }
        .sharedBackgroundVisibility(.hidden)
    }
}

/// Popover content listing saved sessions and a button to start a new one.
struct SessionMenu: View {
    let sessions: [SessionSnapshotMetadata]
    let currentSessionId: String?
    let onSelect: (String) -> Void
    let onNewConversation: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if sessions.isEmpty {
                Text("No conversations")
                    .foregroundStyle(.secondary)
                    .padding(Spacing.sm)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        ForEach(sessions) { metadata in
                            SessionRow(
                                metadata: metadata,
                                isSelected: metadata.sessionId == currentSessionId,
                                onSelect: onSelect
                            )
                        }
                    }
                    .padding(Spacing.xxs)
                }
                .frame(maxHeight: 280)
            }

            Divider()
                .padding(.horizontal, Spacing.xs)

            Button {
                onNewConversation()
            } label: {
                Label("New Conversation", systemImage: "plus")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
        }
        .frame(width: 260)
    }
}

private struct SessionRow: View {
    let metadata: SessionSnapshotMetadata
    let isSelected: Bool
    let onSelect: (String) -> Void

    @State private var isHovered = false

    var body: some View {
        Button {
            onSelect(metadata.sessionId)
        } label: {
            HStack(spacing: Spacing.xs) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(metadata.title.isEmpty ? "Untitled" : metadata.title)
                        .lineLimit(1)
                    Text(metadata.createdAt, format: .relative(presentation: .named))
                        .foregroundStyle(.secondary)
                        .font(.caption)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.secondary)
                        .font(.caption.weight(.semibold))
                }
            }
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, Spacing.xxs)
            .background {
                RoundedRectangle(cornerRadius: Radii.sm, style: .continuous)
                    .fill(.quaternary.opacity(isHovered ? 1 : 0))
            }
            .contentShape(RoundedRectangle(cornerRadius: Radii.sm, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    SessionMenu(
        sessions: [
            SessionSnapshotMetadata(sessionId: "1", savedAt: .now, title: "Refactor auth module"),
            SessionSnapshotMetadata(sessionId: "2", savedAt: .now.addingTimeInterval(-3600), title: "Fix login bug"),
            SessionSnapshotMetadata(sessionId: "3", savedAt: .now.addingTimeInterval(-86400), title: ""),
        ],
        currentSessionId: "1",
        onSelect: { _ in },
        onNewConversation: {}
    )
}
