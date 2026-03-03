import SwiftUI

/// The message input field. TextEditor with placeholder, submit button,
/// and auto-grow behavior.
///
/// Glass material background. Rainbow border on focus with a soft outer glow.
/// Pill shape when single-line, rounded rectangle when multi-line.
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
    let isStreaming: Bool
    let onSubmit: () -> Void
    let onStop: (() -> Void)?

    @FocusState private var isFocused: Bool
    @State private var glowPhase: CGFloat = 0
    @State private var fieldHeight: CGFloat = 48

    public init(
        text: Binding<String>,
        placeholder: String = "Message Claude...",
        isStreaming: Bool = false,
        onSubmit: @escaping () -> Void,
        onStop: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.isStreaming = isStreaming
        self.onSubmit = onSubmit
        self.onStop = onStop
    }

    private var hasText: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The button shows stop (red) when streaming with an empty field.
    private var showsStopButton: Bool {
        isStreaming && !hasText
    }

    /// Pill when single-line, rounded rect when grown.
    private var cornerRadius: CGFloat {
        fieldHeight <= 48 ? fieldHeight / 2 : Radii.lg
    }

    /// Concentric inner radius: outer radius minus the smallest padding.
    private var innerCornerRadius: CGFloat {
        max(cornerRadius - Spacing.xs, 0)
    }

    private var rainbowGradient: AngularGradient {
        AngularGradient(
            colors: AIGlow.colors,
            center: .center,
            angle: .degrees(glowPhase)
        )
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.sm) {
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.conversationBody)
                        .foregroundStyle(.contentTertiary)
                        .padding(.leading, 5)
                        .padding(.top, -4)
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
                    .frame(minHeight: 20, maxHeight: 200)
                    .fixedSize(horizontal: false, vertical: true)
                    .onKeyPress(keys: [.return], phases: .down) { keyPress in
                        if keyPress.modifiers.contains(.shift) {
                            return .ignored
                        }
                        guard hasText else { return .handled }
                        onSubmit()
                        return .handled
                    }
            }

            Button {
                if showsStopButton {
                    onStop?()
                } else {
                    guard hasText else { return }
                    onSubmit()
                }
            } label: {
                Image(systemName: showsStopButton ? "stop.circle.fill" : "arrow.up.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.hierarchical)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .foregroundStyle(showsStopButton ? AnyShapeStyle(.statusError) : AnyShapeStyle(.contentAccent))
            .opacity(isStreaming || hasText ? 1 : 0.3)
            .animation(Motion.morph, value: isStreaming)
            .animation(Motion.morph, value: hasText)
        }
        .clipShape(.rect(cornerRadius: innerCornerRadius, style: .continuous))
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        // Glass background
        .background(
            .ultraThinMaterial,
            in: .rect(cornerRadius: cornerRadius, style: .continuous)
        )
        // Rainbow border
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(rainbowGradient, lineWidth: 1.5)
                .opacity(isFocused ? 0.6 : 0)
                .animation(Motion.morph, value: isFocused)
        )
        // Outer glow on focus
        .background {
            RoundedRectangle(cornerRadius: cornerRadius + 4, style: .continuous)
                .fill(rainbowGradient)
                .blur(radius: 12)
                .opacity(isFocused ? 0.2 : 0)
                .padding(-4)
                .animation(Motion.morph, value: isFocused)
        }
        .animation(Motion.morph, value: cornerRadius)
        .onGeometryChange(for: CGFloat.self, of: \.size.height) { height in
            fieldHeight = height
        }
        .onAppear {
            isFocused = true
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                glowPhase = 360
            }
        }
    }
}
