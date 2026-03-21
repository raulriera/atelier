import CoreGraphics
import AppKit

/// Composites two images into a single PNG.
///
/// Draws `background` first, then `foreground` on top. The output dimensions
/// match the background image. If the foreground is smaller, it draws at its
/// native size in the top-left region. If larger, it is clipped to the
/// background bounds.
///
/// ```swift
/// let pngData = ImageFlattener.flatten(background: photo, foreground: annotations)
/// ```
public enum ImageFlattener {

    /// Composites `foreground` over `background`, returning PNG data.
    public static func flatten(background: CGImage, foreground: CGImage) -> Data? {
        let width = background.width
        let height = background.height

        guard width > 0, height > 0 else { return nil }

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }

        // CGContext uses bottom-left origin. CGContext.draw(_:in:) maps the
        // image into the given rect in context coordinates — no manual flip
        // needed because draw handles the image's internal orientation.
        let bgRect = CGRect(x: 0, y: 0, width: width, height: height)
        context.draw(background, in: bgRect)

        // Draw foreground at its native size, anchored to top-left in screen
        // coordinates. In bottom-left context coords, top-left is (0, height - fgHeight).
        let fgRect = CGRect(
            x: 0,
            y: height - foreground.height,
            width: foreground.width,
            height: foreground.height
        )
        context.draw(foreground, in: fgRect)

        guard let cgImage = context.makeImage() else { return nil }

        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        return bitmap.representation(using: .png, properties: [:])
    }
}
