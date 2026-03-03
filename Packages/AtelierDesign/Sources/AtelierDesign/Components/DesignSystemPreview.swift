import SwiftUI

/// Preview of every design system component.
/// Open in Xcode → Canvas (⌥⌘P) to see live.
struct DesignSystemPreview: View {
    @State private var draftText = ""
    @State private var showCard = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {

                // MARK: - Conversation

                section("Conversation") {
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        HStack {
                            Spacer()
                            Text("Can you review the Q1 numbers and update the summary?")
                                .font(.conversationBody)
                                .foregroundStyle(.contentPrimary)
                                .tintedContainer()
                                .frame(maxWidth: 400)
                        }

                        Text("I'll review the quarterly data and update the summary sheet. Here's what I found:")
                            .font(.conversationBody)
                            .foregroundStyle(.contentPrimary)
                            .plainContainer()

                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: "doc.badge.gearshape")
                                    .foregroundStyle(.contentAccent)
                                Text("quarterly-report.xlsx").font(.cardTitle)
                            }
                            Text("Modified 3 cells · Added \"Charts\" sheet · Updated formula in C15")
                                .font(.cardBody)
                                .foregroundStyle(.contentSecondary)
                            HStack(spacing: Spacing.sm) {
                                Button("Approve") {}.buttonStyle(.glassProminent)
                                Button("View Diff") {}.buttonStyle(.glass)
                                Button("Reject") {}.buttonStyle(.glass(.clear))
                            }
                        }
                        .cardContainer()

                        Label("847 tokens · ~$0.003", systemImage: "number")
                            .labelStyle(.caption)
                            .padding(.leading, Spacing.md)

                        SectionDivider(label: "Earlier today")

                        HStack {
                            Spacer()
                            Text("Session started · Claude 4 Opus").systemContainer()
                            Spacer()
                        }
                    }
                }

                ComposeField(text: $draftText) {}

                // MARK: - Typography

                section("Typography") {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Section Title").font(.sectionTitle)
                        Text("Conversation body — the main message font.").font(.conversationBody)
                        Text("let code = \"monospaced\"").font(.conversationCode)
                        Text("Card Title").font(.cardTitle)
                        Text("Card body text").font(.cardBody)
                        Text("12,847 tokens · $0.04").font(.tokenCount)
                        Text("2 minutes ago").font(.metadata)
                    }
                    .foregroundStyle(.contentPrimary)
                }

                // MARK: - Buttons & Labels

                section("Buttons") {
                    HStack(spacing: Spacing.md) {
                        Button("Send") {}.buttonStyle(.glassProminent)
                        Button("Cancel") {}.buttonStyle(.glass(.clear))
                        Button("View Diff") {}.buttonStyle(.glass)
                    }
                }

                section("Labels") {
                    HStack(spacing: Spacing.lg) {
                        Label("847 tokens", systemImage: "number").labelStyle(.caption)
                        Label("2m ago", systemImage: "clock").labelStyle(.caption)
                        Label("report.pdf", systemImage: "doc").labelStyle(.caption)
                    }
                }

                // MARK: - Motion

                section("Motion") {
                    VStack(spacing: Spacing.md) {
                        Button("Toggle Card") {
                            withAnimation(Motion.appear) {
                                showCard.toggle()
                            }
                        }
                        .buttonStyle(.glass)

                        if showCard {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text("Animated Card").font(.cardTitle)
                                Text("Motion.cardReveal + Motion.appear")
                                    .font(.cardBody)
                                    .foregroundStyle(.contentSecondary)
                            }
                            .cardContainer()
                            .transition(Motion.cardReveal)
                        }
                    }
                }

                // MARK: - Spacing & Radii

                section("Spacing") {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        spacingBar("xxs", value: Spacing.xxs)
                        spacingBar("xs", value: Spacing.xs)
                        spacingBar("sm", value: Spacing.sm)
                        spacingBar("md", value: Spacing.md)
                        spacingBar("lg", value: Spacing.lg)
                        spacingBar("xl", value: Spacing.xl)
                        spacingBar("xxl", value: Spacing.xxl)
                    }
                }
            }
            .padding(Spacing.xl)
        }
        .frame(minWidth: 600, minHeight: 800)
        .background(.surfaceDefault)
    }

    // MARK: - Helpers

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title).font(.sectionTitle).foregroundStyle(.contentPrimary)
            content()
        }
    }

    private func spacingBar(_ label: String, value: CGFloat) -> some View {
        HStack(spacing: Spacing.xs) {
            Text(label)
                .font(.conversationCode)
                .foregroundStyle(.contentSecondary)
                .frame(width: 32, alignment: .trailing)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(.contentAccent)
                .frame(width: value * 4, height: 12)
            Text("\(Int(value))pt")
                .font(.tokenCount)
                .foregroundStyle(.contentTertiary)
        }
    }
}

#Preview("Design System") {
    DesignSystemPreview()
        .preferredColorScheme(.light)
}

#Preview("Design System (Dark)") {
    DesignSystemPreview()
        .preferredColorScheme(.dark)
}
