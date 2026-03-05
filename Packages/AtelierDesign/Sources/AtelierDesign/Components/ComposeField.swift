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
    @Environment(\.controlActiveState) private var controlActiveState
    @State private var fieldHeight: CGFloat = 48

    public init(
        text: Binding<String>,
        placeholder: String = "Let's knock something off your plate...",
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

    /// Show the rainbow glow only when the field is focused AND the window is key.
    /// Background windows keep their focus state but skip the gradient rendering.
    private var showsGlow: Bool {
        isFocused && controlActiveState == .key
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
                    .offset(y: -2)
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
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, showsStopButton ? AnyShapeStyle(.statusError) : AnyShapeStyle(.contentAccent))
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
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
        // Static rainbow border
        .overlay {
            if showsGlow {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(AIGlow.angular, lineWidth: 1.5)
                    .opacity(0.6)
                    .transition(.opacity)
            }
        }
        // Static outer glow
        .background {
            if showsGlow {
                RoundedRectangle(cornerRadius: cornerRadius + 4, style: .continuous)
                    .fill(AIGlow.angular)
                    .blur(radius: 12)
                    .opacity(0.2)
                    .padding(-4)
                    .transition(.opacity)
            }
        }
        .animation(Motion.morph, value: showsGlow)
        .animation(Motion.morph, value: cornerRadius)
        .onGeometryChange(for: CGFloat.self, of: \.size.height) { height in
            fieldHeight = height
        }
        .onAppear {
            isFocused = true
        }
    }
}
