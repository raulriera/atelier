import SwiftUI

/// The message input field. TextEditor with placeholder, submit button,
/// and auto-grow behavior.
///
/// Glass material background. Rainbow border on focus with a soft outer glow.
/// Pill shape when single-line, rounded rectangle when multi-line.
///
/// An optional `header` slot renders above the text editor, inside the
/// glowing container — use it for attachment strips or other contextual
/// content that should grow the field.
///
/// Usage:
/// ```swift
/// ComposeField(text: $draft, placeholder: "Message Claude...") {
///     sendMessage()
/// }
///
/// // With a header:
/// ComposeField(text: $draft, onSubmit: { send() }) {
///     AttachmentStrip(attachments: $files)
/// }
/// ```
public struct ComposeField<Header: View>: View {
    @Binding var text: String
    let placeholder: String
    let isStreaming: Bool
    let onSubmit: () -> Void
    let onStop: (() -> Void)?
    let header: Header

    @FocusState private var isFocused: Bool
    @State private var fieldHeight: CGFloat = 48

    public init(
        text: Binding<String>,
        placeholder: String = "Let's knock something off your plate...",
        isStreaming: Bool = false,
        onSubmit: @escaping () -> Void,
        onStop: (() -> Void)? = nil,
        @ViewBuilder header: () -> Header
    ) {
        self._text = text
        self.placeholder = placeholder
        self.isStreaming = isStreaming
        self.onSubmit = onSubmit
        self.onStop = onStop
        self.header = header()
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

    public var body: some View {
        VStack(spacing: 0) {
            header

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
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
        }
        .clipShape(.rect(cornerRadius: cornerRadius, style: .continuous))
        .glowingFieldContainer(isFocused: isFocused, cornerRadius: cornerRadius)
        .animation(Motion.morph, value: cornerRadius)
        .onGeometryChange(for: CGFloat.self, of: \.size.height) { height in
            fieldHeight = height
        }
        .onAppear {
            isFocused = true
        }
    }
}

extension ComposeField where Header == EmptyView {
    /// Creates a compose field without a header.
    public init(
        text: Binding<String>,
        placeholder: String = "Let's knock something off your plate...",
        isStreaming: Bool = false,
        onSubmit: @escaping () -> Void,
        onStop: (() -> Void)? = nil
    ) {
        self.init(
            text: text,
            placeholder: placeholder,
            isStreaming: isStreaming,
            onSubmit: onSubmit,
            onStop: onStop
        ) {
            EmptyView()
        }
    }
}
