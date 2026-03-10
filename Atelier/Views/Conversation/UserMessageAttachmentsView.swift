import SwiftUI
import AtelierDesign
import AtelierKit

/// Displays file attachments in a stacked "paper pile" layout
/// using a ZStack with slight random rotations, inspired by
/// iMessage's photo stack.
///
/// Images get large thumbnails; non-previewable files show a
/// placeholder card with the file icon and name (no bubble/tail).
struct UserMessageAttachmentsView: View {
    let attachments: [FileAttachment]

    /// Thumbnail size for the stack.
    private static let thumbnailSize: CGFloat = 200

    var body: some View {
        HStack {
            Spacer(minLength: Spacing.xxl)
            ZStack {
                ForEach(Array(attachments.enumerated()), id: \.element.id) { index, attachment in
                    if attachment.kind == .image {
                        imageAttachment(attachment, index: index)
                    } else {
                        fileAttachment(attachment, index: index)
                    }
                }
            }
            .frame(width: Self.thumbnailSize, height: Self.thumbnailSize)
        }
    }

    private func imageAttachment(_ attachment: FileAttachment, index: Int) -> some View {
        let offset = translation(for: attachment, index: index)
        return AttachmentThumbnailView(attachment: attachment, size: Self.thumbnailSize)
            .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
            .rotationEffect(rotation(for: attachment, index: index))
            .offset(x: offset.x, y: offset.y)
    }

    private func fileAttachment(_ attachment: FileAttachment, index: Int) -> some View {
        let offset = translation(for: attachment, index: index)
        return VStack(spacing: Spacing.xxs) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: attachment.url.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 40, height: 40)

            Text(attachment.filename)
                .font(.caption2)
                .foregroundStyle(.contentSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(width: 120, height: 120)
        .plainContainer(showsTail: false)
        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
        .rotationEffect(rotation(for: attachment, index: index))
        .offset(x: offset.x, y: offset.y)
    }

    /// Fixed per-count layouts so the pile looks intentional, not random.
    /// Each entry is (rotation°, offsetX, offsetY) for one card.
    private static let layouts: [[(Double, Double, Double)]] = [
        // 1 attachment — centered, straight
        [(0, 0, 0)],
        // 2 attachments — back tilted left, front tilted right
        [(-6, -14, -4), (5, 10, 2)],
        // 3 attachments — fan spread
        [(-8, -18, -6), (6, 16, 4), (1, -2, -1)],
        // 4 attachments
        [(-9, -22, -5), (7, 18, 3), (-3, -4, -8), (4, 8, 6)],
        // 5 attachments
        [(-10, -24, -6), (8, 20, 4), (-4, -6, -10), (5, 10, 8), (1, 2, -2)],
    ]

    /// Deterministic rotation based on attachment count and index.
    private func rotation(for attachment: FileAttachment, index: Int) -> Angle {
        let count = min(attachments.count, Self.layouts.count)
        let layout = Self.layouts[count - 1]
        let entry = layout[min(index, layout.count - 1)]
        return .degrees(entry.0)
    }

    /// Deterministic offset based on attachment count and index.
    private func translation(for attachment: FileAttachment, index: Int) -> CGPoint {
        let count = min(attachments.count, Self.layouts.count)
        let layout = Self.layouts[count - 1]
        let entry = layout[min(index, layout.count - 1)]
        return CGPoint(x: entry.1, y: entry.2)
    }
}

#Preview("1 attachment") {
    UserMessageAttachmentsView(attachments: [
        FileAttachment(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/Sequoia.heic")),
    ])
    .padding()
    .frame(width: 600)
}

#Preview("2 attachments") {
    UserMessageAttachmentsView(attachments: [
        FileAttachment(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/Sequoia.heic")),
        FileAttachment(url: URL(fileURLWithPath: "/usr/bin/swift")),
    ])
    .padding()
    .frame(width: 600)
}

#Preview("3 attachments") {
    UserMessageAttachmentsView(attachments: [
        FileAttachment(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/Sequoia.heic")),
        FileAttachment(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/Sequoia.heic")),
        FileAttachment(url: URL(fileURLWithPath: "/usr/bin/swift")),
    ])
    .padding()
    .frame(width: 600)
}

#Preview("4 attachments") {
    UserMessageAttachmentsView(attachments: [
        FileAttachment(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/Sequoia.heic")),
        FileAttachment(url: URL(fileURLWithPath: "/usr/bin/swift")),
        FileAttachment(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/Sequoia.heic")),
        FileAttachment(url: URL(fileURLWithPath: "/usr/bin/swift")),
    ])
    .padding()
    .frame(width: 600)
}

#Preview("5 attachments") {
    UserMessageAttachmentsView(attachments: [
        FileAttachment(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/Sequoia.heic")),
        FileAttachment(url: URL(fileURLWithPath: "/usr/bin/swift")),
        FileAttachment(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/Sequoia.heic")),
        FileAttachment(url: URL(fileURLWithPath: "/usr/bin/swift")),
        FileAttachment(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/Sequoia.heic")),
    ])
    .padding()
    .frame(width: 600)
}
