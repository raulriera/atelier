import SwiftUI
import AtelierDesign
import AtelierKit

struct CapabilitiesCard: View {
    @Bindable var capabilityStore: CapabilityStore

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            header
            content
        }
        .cardContainer()
        .frame(width: 280)
    }

    private var header: some View {
        HStack {
            Text("Capabilities")
                .font(.cardTitle)
                .foregroundStyle(.contentPrimary)

            Spacer()
        }
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
        VStack(spacing: Spacing.xs) {
            Image(systemName: "puzzlepiece.extension")
                .font(.title2)
                .foregroundStyle(.contentTertiary)

            Text("No capabilities available in this build")
                .font(.metadata)
                .foregroundStyle(.contentTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.md)
    }

    private var capabilityList: some View {
        VStack(spacing: 0) {
            ForEach(capabilityStore.capabilities) { capability in
                CapabilityRow(
                    capability: capability,
                    isEnabled: capabilityStore.isEnabled(capability.id)
                ) {
                    capabilityStore.toggle(capability.id)
                }
            }
        }
        .animation(Motion.settle, value: capabilityStore.enabledIDs)
    }
}
