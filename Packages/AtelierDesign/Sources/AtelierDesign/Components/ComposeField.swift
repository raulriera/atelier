import SwiftUI

/// The message input field. TextEditor with placeholder, submit button,
/// and auto-grow behavior.
///
/// Features a subtle AI glow border that slowly rotates — the rainbow
/// shimmer signals "this is where you talk to AI."
///
/// Usage:
/// ```swift
/// ComposeField(text: $draft, placeholder: "Message Claude...") {
///     sendMessage()
/// }
/// ```
public struct ComposeField: View {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool
    @State private var glowPhase: CGFloat = 0

    public init(
        text: Binding<String>,
        placeholder: String = "Message Claude...",
        onSubmit: @escaping () -> Void
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onSubmit = onSubmit
    }

    private var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.sm) {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundStyle(.contentTertiary)
                        .padding(.leading, 5) // matches NSTextView lineFragmentPadding
                        .allowsHitTesting(false)
                }

                TextEditor(text: $text)
                    .focused($isFocused)
                    .font(.conversationBody)
                    .foregroundStyle(.contentPrimary)
                    .textEditorStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .contentMargins(.all, 0, for: .scrollContent)
                    .scrollIndicators(.hidden)
                    .frame(minHeight: 24, maxHeight: 200)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                guard hasText else { return }
                onSubmit()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.contentAccent)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .opacity(hasText ? 1 : 0.3)
            .animation(Motion.morph, value: hasText)
        }
        .padding(Spacing.sm)
        .background(.surfaceElevated, in: .rect(cornerRadius: Radii.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radii.lg, style: .continuous)
                .strokeBorder(
                    AngularGradient(
                        colors: AIGlow.colors,
                        center: .center,
                        angle: .degrees(glowPhase)
                    )
                    .opacity(isFocused ? 0.6 : 0.25),
                    lineWidth: 1.5
                )
        )
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                glowPhase = 360
            }
        }
    }
}
