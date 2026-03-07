import SwiftUI
import AtelierDesign
import AtelierKit

/// Sheet presenting all capabilities with expandable tool group toggles.
struct CapabilitiesSheet: View {
    @Bindable var capabilityStore: CapabilityStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Capabilities")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .frame(minWidth: 440, idealWidth: 480, minHeight: 300, idealHeight: 440)
    }

    @ViewBuilder
    private var content: some View {
        if capabilityStore.capabilities.isEmpty {
            emptyState
        } else {
            capabilityList
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "puzzlepiece.extension")
                .font(.largeTitle)
                .foregroundStyle(.contentTertiary)

            Text("No capabilities available in this build")
                .font(.cardBody)
                .foregroundStyle(.contentTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var capabilityList: some View {
        List {
            Text("Let Claude work with apps on your Mac. Each capability connects to an app and can be customized.")
                .font(.cardBody)
                .foregroundStyle(.contentSecondary)
                .listRowSeparator(.hidden)

            ForEach(capabilityStore.capabilities) { capability in
                CapabilityRow(
                    capability: capability,
                    capabilityStore: capabilityStore
                )
            }
        }
    }
}

/// A capability row that navigates to a detail view for tool group toggles.
private struct CapabilityRow: View {
    let capability: Capability
    @Bindable var capabilityStore: CapabilityStore

    private var isEnabled: Bool {
        capabilityStore.isEnabled(capability.id)
    }

    var body: some View {
        if capability.toolGroups.isEmpty {
            row
        } else {
            NavigationLink {
                CapabilityDetail(
                    capability: capability,
                    capabilityStore: capabilityStore
                )
            } label: {
                row
            }
        }
    }

    private var row: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: capability.iconSystemName)
                .font(.title2)
                .foregroundStyle(.contentAccent)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(capability.name)
                    .font(.cardBody)
                    .foregroundStyle(.contentPrimary)
                    .lineLimit(1)

                Text(capability.description)
                    .font(.metadata)
                    .foregroundStyle(.contentSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { _ in capabilityStore.toggle(capability.id) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
        }
    }
}

/// Detail view showing tool group toggles for a capability.
private struct CapabilityDetail: View {
    let capability: Capability
    @Bindable var capabilityStore: CapabilityStore

    var body: some View {
        List(capability.toolGroups) { group in
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
                    get: { capabilityStore.isGroupEnabled(group.id, for: capability.id) },
                    set: { _ in capabilityStore.toggleGroup(group.id, for: capability.id) }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
            }
        }
        .navigationTitle(capability.name)
    }
}

#Preview {
    CapabilitiesSheet(capabilityStore: CapabilityStore())
}
