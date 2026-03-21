import SwiftUI
import AppKit
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
            thumbnailContent(for: attachment)

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

    @ViewBuilder
    private func thumbnailContent(for attachment: FileAttachment) -> some View {
        let thumbnail = AttachmentThumbnailView(attachment: attachment, size: 56)
            .padding(Spacing.xxs)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: Radii.sm, style: .continuous))

        if attachment.kind == .image {
            Button { annotate(attachment) } label: { thumbnail }
                .buttonStyle(.plain)
        } else {
            thumbnail
        }
    }

    private func annotate(_ attachment: FileAttachment) {
        let url = attachment.url
        let originalID = attachment.id

        Task {
            // Load off main thread — the file may need to download from iCloud.
            guard let image = try? await Task.detached(operation: {
                NSImage(contentsOf: url)
            }).value else { return }

            SketchWindowController.open(backgroundImage: image) { pngData in
                guard let newAttachment = try? FileAttachment.fromImageData(pngData),
                      let idx = attachments.firstIndex(where: { $0.id == originalID }) else { return }
                withAnimation(Motion.morph) {
                    attachments[idx] = newAttachment
                }
            }
        }
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
