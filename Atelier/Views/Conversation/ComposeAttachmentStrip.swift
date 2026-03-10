import SwiftUI
import AtelierDesign
import AtelierKit

/// Horizontal scrolling strip of attachment thumbnails shown above
/// the compose field when files are pending.
///
/// Each thumbnail has a dismiss button. The strip auto-scrolls
/// to show the latest addition.
struct ComposeAttachmentStrip: View {
    @Binding var attachments: [FileAttachment]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            GlassEffectContainer(spacing: Spacing.xs) {
                HStack(spacing: Spacing.xs) {
                    ForEach(attachments) { attachment in
                        attachmentCard(attachment)
                    }
                }
            }
        }
        .scrollClipDisabled()
    }

    private func attachmentCard(_ attachment: FileAttachment) -> some View {
        ZStack(alignment: .topTrailing) {
            AttachmentThumbnailView(attachment: attachment, size: 56)
                .padding(Spacing.xxs)
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: Radii.sm, style: .continuous))

            Button {
                withAnimation(Motion.morph) {
                    attachments.removeAll { $0.id == attachment.id }
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption2.weight(.bold))
                    .padding(Spacing.xxs)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .offset(x: 4, y: -4)
        }
        .transition(.scale.combined(with: .opacity))
    }
}

#Preview {
    @Previewable @State var attachments: [FileAttachment] = [
        FileAttachment(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/Sequoia.heic")),
        FileAttachment(url: URL(fileURLWithPath: "/usr/bin/swift")),
    ]

    ComposeAttachmentStrip(attachments: $attachments)
        .padding()
        .frame(width: 400)
}
