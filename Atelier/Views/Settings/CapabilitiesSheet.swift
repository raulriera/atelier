import SwiftUI
import AtelierDesign
import AtelierKit

/// Card-grid sheet for managing capabilities, inspired by Claude's plugin
/// browser and Shortcuts Gallery. Tap a card to see tool group controls.
struct CapabilitiesSheet: View {
    @Bindable var capabilityStore: CapabilityStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedCapability: Capability?

    private let columns = [
        GridItem(.adaptive(minimum: 200, maximum: 280), spacing: Spacing.md)
    ]

    var body: some View {
        Group {
            if capabilityStore.capabilities.isEmpty {
                emptyState
            } else if let capability = selectedCapability {
                CapabilityDetailView(
                    capability: capability,
                    capabilityStore: capabilityStore,
                    onBack: { selectedCapability = nil }
                )
            } else {
                cardGrid
            }
        }
        .frame(minWidth: 520, idealWidth: 640, minHeight: 360, idealHeight: 480)
        .animation(Motion.morph, value: selectedCapability?.id)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "puzzlepiece.extension")
                .font(.largeTitle)
                .foregroundStyle(.contentTertiary)

            Text("No capabilities available")
                .font(.cardBody)
                .foregroundStyle(.contentTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Grid

    private var cardGrid: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.md)

            ScrollView {
                LazyVGrid(columns: columns, spacing: Spacing.md) {
                    ForEach(capabilityStore.capabilities) { capability in
                        CapabilityCard(
                            capability: capability,
                            isEnabled: capabilityStore.isEnabled(capability.id)
                        )
                        .onTapGesture { selectedCapability = capability }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.lg)
            }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("Capabilities")
                    .font(.title2)
                    .foregroundStyle(.contentPrimary)

                Text("Extend what Claude can do with macOS apps.")
                    .font(.cardBody)
                    .foregroundStyle(.contentSecondary)
            }

            Spacer()

            Button("Done") { dismiss() }
                .buttonStyle(.glass)
        }
    }
}

// MARK: - Card

/// A single capability card: icon, name, description. Tappable.
private struct CapabilityCard: View {
    let capability: Capability
    let isEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .top) {
                Image(systemName: capability.iconSystemName)
                    .font(.title2)
                    .foregroundStyle(.contentPrimary)

                Spacer()

                if isEnabled {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.contentSecondary)
                }
            }

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(capability.name)
                    .font(.cardBody)
                    .foregroundStyle(.contentPrimary)
                    .lineLimit(1)

                Text(capability.description)
                    .font(.metadata)
                    .foregroundStyle(.contentSecondary)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.xs)
        .cardContainer()
    }
}

// MARK: - Detail

/// Detail view for a single capability showing tool group toggles.
private struct CapabilityDetailView: View {
    let capability: Capability
    @Bindable var capabilityStore: CapabilityStore
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            detailHeader
                .padding(.horizontal, Spacing.lg)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.md)

            if !capability.toolGroups.isEmpty {
                ScrollView {
                    VStack(spacing: Spacing.xs) {
                        ForEach(capability.toolGroups) { group in
                            toolGroupRow(group)
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.lg)
                }
            } else {
                Spacer()

                Text("This capability has no configurable tool groups.")
                    .font(.cardBody)
                    .foregroundStyle(.contentTertiary)

                Spacer()
            }
        }
    }

    private var detailHeader: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.backward")
            }
            .buttonStyle(.glass)

            Text(capability.name)
                .font(.title2)
                .foregroundStyle(.contentPrimary)

            Spacer()
        }
    }

    private func toolGroupRow(_ group: ToolGroup) -> some View {
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
        .padding(Spacing.xs)
        .cardContainer()
    }
}

#Preview("With capabilities") {
    CapabilitiesSheet(capabilityStore: .preview)
}

#Preview("Empty") {
    CapabilitiesSheet(capabilityStore: CapabilityStore())
}
