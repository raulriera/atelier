import SwiftUI

/// A styled divider for separating conversation sections.
///
/// Usage:
/// ```swift
/// SectionDivider()
/// SectionDivider(label: "Earlier today")
/// ```
public struct SectionDivider: View {
    let label: String?

    public init(label: String? = nil) {
        self.label = label
    }

    public var body: some View {
        HStack(spacing: Spacing.sm) {
            line
            if let label {
                Text(label)
                    .font(.metadata)
                    .foregroundStyle(.contentTertiary)
                line
            }
        }
        .padding(.vertical, Spacing.xs)
    }

    private var line: some View {
        Rectangle()
            .fill(.contentTertiary.opacity(0.3))
            .frame(height: 0.5)
    }
}
