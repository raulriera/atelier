import SwiftUI
import QuickLookThumbnailing
import AtelierDesign
import AtelierKit

/// Displays a thumbnail for a file attachment using QuickLook.
///
/// Images, PDFs, and many document types get rich previews via
/// `QLThumbnailGenerator`. Unsupported types fall back to the
/// system file icon from `NSWorkspace`.
///
/// Usage:
/// ```swift
/// AttachmentThumbnailView(attachment: file, size: 64)
/// ```
struct AttachmentThumbnailView: View {
    let attachment: FileAttachment
    var size: CGFloat = 64

    @State private var thumbnail: NSImage?

    var body: some View {
        Group {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                fallbackIcon
            }
        }
        .frame(width: size, height: size)
        .clipShape(.rect(cornerRadius: Radii.sm, style: .continuous))
        .task(id: attachment.id) {
            thumbnail = await Self.generateThumbnail(
                for: attachment.url,
                size: CGSize(width: size * 2, height: size * 2)
            )
        }
    }

    private var fallbackIcon: some View {
        ZStack {
            Color(.controlBackgroundColor).opacity(0.5)
            Image(nsImage: NSWorkspace.shared.icon(forFile: attachment.url.path))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(Spacing.xs)
        }
    }

    private static func generateThumbnail(for url: URL, size: CGSize) async -> NSImage? {
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: 2.0,
            representationTypes: .thumbnail
        )
        let representation = try? await QLThumbnailGenerator.shared
            .generateBestRepresentation(for: request)
        return representation?.nsImage
    }
}

#Preview {
    HStack {
        AttachmentThumbnailView(
            attachment: FileAttachment(url: URL(fileURLWithPath: "/System/Library/Desktop Pictures/Sequoia.heic"))
        )
        AttachmentThumbnailView(
            attachment: FileAttachment(url: URL(fileURLWithPath: "/usr/bin/swift"))
        )
    }
    .padding()
}
