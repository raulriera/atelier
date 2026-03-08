import SwiftUI
import AtelierDesign
import AtelierKit

/// Card-grid view for managing capabilities, inspired by Claude's plugin
/// browser and Shortcuts Gallery. Tap a card to expand tool group controls.
struct CapabilitiesInspector: View {
    @Bindable var capabilityStore: CapabilityStore
    @State private var expandedCapability: String?

    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 280), spacing: Spacing.md)
    ]

    var body: some View {
        if capabilityStore.capabilities.isEmpty {
            emptyState
        } else {
            cardGrid
        }
    }

    // MARK: - Empty

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Capabilities", systemImage: "puzzlepiece.extension")
        } description: {
            Text("Capabilities appear here when available")
        }
    }

    // MARK: - Grid

    private var cardGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Spacing.md) {
                ForEach(capabilityStore.capabilities) { capability in
                    Button {
                        withAnimation(Motion.morph) {
                            expandedCapability = expandedCapability == capability.id ? nil : capability.id
                        }
                    } label: {
                        CapabilityCard(
                            capability: capability,
                            isExpanded: expandedCapability == capability.id,
                            isGroupEnabled: { groupID in
                                capabilityStore.isGroupEnabled(groupID, for: capability.id)
                            },
                            onToggleGroup: { groupID in
                                capabilityStore.toggleGroup(groupID, for: capability.id)
                            }
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(Spacing.md)
        }
    }
}

// MARK: - Card

/// A single capability card: icon, name, description. Expands to show tool group toggles.
private struct CapabilityCard: View {
    let capability: Capability
    let isExpanded: Bool
    let isGroupEnabled: (String) -> Bool
    let onToggleGroup: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .top) {
                Image(systemName: capability.iconSystemName)
                    .font(.title2)
                    .foregroundStyle(.contentPrimary)

                Text(capability.name)
                    .font(.cardBody)
                    .foregroundStyle(.contentPrimary)
                    .lineLimit(1)
            }

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(capability.description)
                    .font(.metadata)
                    .foregroundStyle(.contentSecondary)
                    .lineLimit(isExpanded ? nil : 3)
            }

            if isExpanded && !capability.toolGroups.isEmpty {
                Divider()

                ForEach(capability.toolGroups) { group in
                    HStack(spacing: Spacing.sm) {
                        VStack(alignment: .leading, spacing: Spacing.xxs) {
                            Text(group.name)
                                .font(.cardBody)
                                .foregroundStyle(.contentPrimary)
                                .lineLimit(1)

                            Text(group.description)
                                .font(.metadata)
                                .foregroundStyle(.contentSecondary)
                                .lineLimit(2)
                        }

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { isGroupEnabled(group.id) },
                            set: { _ in onToggleGroup(group.id) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.xs)
        .cardContainer()
    }
}

#Preview("With capabilities") {
    CapabilitiesInspector(capabilityStore: .preview)
        .frame(width: 320, height: 500)
}

#Preview("Empty") {
    CapabilitiesInspector(capabilityStore: CapabilityStore())
        .frame(width: 320, height: 500)
}
