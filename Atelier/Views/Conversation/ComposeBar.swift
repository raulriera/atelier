import SwiftUI
import AtelierDesign
import AtelierKit

/// The bottom compose area
///
/// Contains the add menu (Sketch / Attach Files), the text field with
/// attachment strip header, and the submit/stop button. Presented as
/// a bottom safe-area inset in the conversation window.
struct ComposeBar: View {
    @Binding var draft: String
    @Binding var pendingAttachments: [FileAttachment]
    @Binding var showAttachmentPicker: Bool
    let isStreaming: Bool
    let cliAvailable: Bool
    let onSubmit: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: Spacing.xs) {
            ComposeAddMenu(
                pendingAttachments: $pendingAttachments,
                showAttachmentPicker: $showAttachmentPicker
            )

            ComposeField(
                text: $draft,
                onSubmit: onSubmit
            ) {
                if !pendingAttachments.isEmpty {
                    ComposeAttachmentStrip(attachments: $pendingAttachments)
                        .padding(.top, Spacing.sm)
                        .padding(.horizontal, Spacing.sm)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            ComposeSubmitButton(
                isStreaming: isStreaming,
                hasText: !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                onSubmit: onSubmit,
                onStop: onStop
            )
        }
        .animation(Motion.morph, value: pendingAttachments.isEmpty)
        .disabled(!cliAvailable)
        .frame(maxWidth: Layout.readingWidth * 1.15)
        .padding(Spacing.md)
        .background {
            Rectangle()
                .fill(.bar)
                .mask {
                    LinearGradient(
                        colors: [.clear, .black],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }
}

// MARK: - Add Menu

/// Glass circle `+` button that opens a menu with Sketch and Attach Files.
private struct ComposeAddMenu: View {
    @Binding var pendingAttachments: [FileAttachment]
    @Binding var showAttachmentPicker: Bool

    var body: some View {
        Menu {
            Button {
                SketchWindowController.open { imageData in
                    if let attachment = try? FileAttachment.fromImageData(imageData) {
                        withAnimation(Motion.morph) {
                            pendingAttachments.append(attachment)
                        }
                    }
                }
            } label: {
                Label("Sketch", systemImage: "pencil.and.scribble")
            }

            Button {
                showAttachmentPicker = true
            } label: {
                Label("Attach Files", systemImage: "paperclip")
            }
        } label: {
            Image(systemName: "plus")
                .font(.body.weight(.semibold))
                .foregroundStyle(.contentSecondary)
                .frame(width: 28, height: 28)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .padding(.bottom, Spacing.xxs)
    }
}

// MARK: - Submit / Stop Button

/// Glass circle submit button. Shows stop icon when streaming with empty field.
private struct ComposeSubmitButton: View {
    let isStreaming: Bool
    let hasText: Bool
    let onSubmit: () -> Void
    let onStop: () -> Void

    private var showStop: Bool {
        isStreaming && !hasText
    }

    var body: some View {
        Button {
            if showStop {
                onStop()
            } else {
                guard hasText else { return }
                onSubmit()
            }
        } label: {
            Image(systemName: showStop ? "stop.fill" : "arrow.up")
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .glassEffect(
                    .regular.tint(showStop ? .red : .accentColor).interactive(),
                    in: .circle
                )
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .opacity(isStreaming || hasText ? 1 : 0.3)
        .animation(Motion.morph, value: isStreaming)
        .animation(Motion.morph, value: hasText)
        .padding(.bottom, Spacing.xxs)
    }
}

#Preview {
    @Previewable @State var draft = ""
    @Previewable @State var attachments: [FileAttachment] = []
    @Previewable @State var showPicker = false

    VStack {
        Spacer()
        ComposeBar(
            draft: $draft,
            pendingAttachments: $attachments,
            showAttachmentPicker: $showPicker,
            isStreaming: false,
            cliAvailable: true,
            onSubmit: {},
            onStop: {}
        )
    }
    .frame(width: 600, height: 200)
}
