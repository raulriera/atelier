import SwiftUI
import AtelierDesign
import AtelierKit

struct CapabilityRow: View {
    let capability: Capability
    let isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: capability.iconSystemName)
                .foregroundStyle(.contentAccent)

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(capability.name)
                    .font(.cardTitle)
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
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
        }
        .padding(.vertical, Spacing.xxs)
    }
}
