import Testing
import CoreGraphics
import AppKit
@testable import AtelierKit

@Suite("ImageFlattener")
struct ImageFlattenerTests {

    // MARK: - Helpers

    /// Creates a solid-color CGImage of the given size.
    private func solidImage(width: Int, height: Int, red: UInt8, green: UInt8, blue: UInt8, alpha: UInt8 = 255) -> CGImage {
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        let color = CGColor(
            colorSpace: colorSpace,
            components: [CGFloat(red) / 255, CGFloat(green) / 255, CGFloat(blue) / 255, CGFloat(alpha) / 255]
        )!
        context.setFillColor(color)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()!
    }

    /// Creates a 4×4 image with red in the top-left quadrant and blue in the bottom-right.
    /// Used to verify orientation is preserved (no flipping).
    private func orientationTestImage() -> CGImage {
        let width = 4, height = 4
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!

        // CGContext has bottom-left origin. Fill everything black first.
        context.setFillColor(CGColor(colorSpace: colorSpace, components: [0, 0, 0, 1])!)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        // Red in top-left quadrant (in screen coords = top-left of final image).
        // In CGContext coords (bottom-left origin), top-left is (0, height/2).
        context.setFillColor(CGColor(colorSpace: colorSpace, components: [1, 0, 0, 1])!)
        context.fill(CGRect(x: 0, y: height / 2, width: width / 2, height: height / 2))

        // Blue in bottom-right quadrant (in screen coords).
        // In CGContext coords, bottom-right is (width/2, 0).
        context.setFillColor(CGColor(colorSpace: colorSpace, components: [0, 0, 1, 1])!)
        context.fill(CGRect(x: width / 2, y: 0, width: width / 2, height: height / 2))

        return context.makeImage()!
    }

    /// Reads RGBA pixel values from a CGImage at the given (x, y) in top-left origin coords.
    /// Note: Only reliable for fully opaque or fully transparent pixels due to premultiplied alpha.
    private func pixel(in image: CGImage, x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        let width = image.width
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(
            data: nil,
            width: width,
            height: image.height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let data = context.data else { return (0, 0, 0, 0) }

        // After draw + makeImage + PNG round-trip, the decoded CGImage is drawn
        // into this context top-down. Row 0 in the buffer ends up as the top row
        // of the image in screen coordinates, so no Y flip is needed.
        let offset = (y * width + x) * 4
        let ptr = data.assumingMemoryBound(to: UInt8.self)
        return (ptr[offset], ptr[offset + 1], ptr[offset + 2], ptr[offset + 3])
    }

    /// Creates a fully transparent CGImage of the given size.
    private func transparentImage(width: Int, height: Int) -> CGImage {
        solidImage(width: width, height: height, red: 0, green: 0, blue: 0, alpha: 0)
    }

    // MARK: - Tests

    @Test("output dimensions match background")
    func outputDimensionsMatchBackground() throws {
        let bg = solidImage(width: 100, height: 50, red: 255, green: 0, blue: 0)
        let fg = solidImage(width: 100, height: 50, red: 0, green: 0, blue: 0, alpha: 0)
        let data = try #require(ImageFlattener.flatten(background: bg, foreground: fg))
        let provider = CGDataProvider(data: data as CFData)!
        let output = try #require(CGImage(pngDataProviderSource: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        #expect(output.width == 100)
        #expect(output.height == 50)
    }

    @Test("orientation preserved — red stays top-left, blue stays bottom-right")
    func orientationPreserved() throws {
        let bg = orientationTestImage()
        let fg = transparentImage(width: 4, height: 4)
        let data = try #require(ImageFlattener.flatten(background: bg, foreground: fg))

        let provider = CGDataProvider(data: data as CFData)!
        let output = try #require(CGImage(pngDataProviderSource: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))

        // Top-left pixel (0,0) should be red
        let topLeft = pixel(in: output, x: 0, y: 0)
        #expect(topLeft.r == 255)
        #expect(topLeft.g == 0)
        #expect(topLeft.b == 0)

        // Bottom-right pixel (3,3) should be blue
        let bottomRight = pixel(in: output, x: 3, y: 3)
        #expect(bottomRight.r == 0)
        #expect(bottomRight.g == 0)
        #expect(bottomRight.b == 255)

        // Top-right pixel (3,0) should be black (not red or blue)
        let topRight = pixel(in: output, x: 3, y: 0)
        #expect(topRight.r == 0)
        #expect(topRight.g == 0)
        #expect(topRight.b == 0)
    }

    @Test("round-trip — flattened PNG loads as NSImage with correct dimensions")
    func roundTrip() throws {
        let bg = solidImage(width: 64, height: 32, red: 128, green: 64, blue: 200)
        let fg = transparentImage(width: 64, height: 32)
        let data = try #require(ImageFlattener.flatten(background: bg, foreground: fg))
        let nsImage = try #require(NSImage(data: data))
        // NSImage size may differ from pixel dimensions (points vs pixels),
        // but the underlying CGImage should match.
        let cgImage = try #require(nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil))
        #expect(cgImage.width == 64)
        #expect(cgImage.height == 32)
    }

    @Test("opaque foreground occludes background")
    func foregroundOccludesBackground() throws {
        let bg = solidImage(width: 4, height: 4, red: 255, green: 0, blue: 0)
        let fg = solidImage(width: 4, height: 4, red: 0, green: 255, blue: 0)
        let data = try #require(ImageFlattener.flatten(background: bg, foreground: fg))
        let provider = CGDataProvider(data: data as CFData)!
        let output = try #require(CGImage(pngDataProviderSource: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))

        let p = pixel(in: output, x: 1, y: 1)
        #expect(p.r == 0)
        #expect(p.g == 255)
        #expect(p.b == 0)
    }

    @Test("transparent foreground preserves background")
    func transparentForegroundPreservesBackground() throws {
        let bg = solidImage(width: 4, height: 4, red: 255, green: 0, blue: 0)
        let fg = transparentImage(width: 4, height: 4)
        let data = try #require(ImageFlattener.flatten(background: bg, foreground: fg))
        let provider = CGDataProvider(data: data as CFData)!
        let output = try #require(CGImage(pngDataProviderSource: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))

        let p = pixel(in: output, x: 1, y: 1)
        #expect(p.r == 255)
        #expect(p.g == 0)
        #expect(p.b == 0)
    }

    @Test("foreground smaller than background — background visible around edges")
    func foregroundSmallerThanBackground() throws {
        let bg = solidImage(width: 10, height: 10, red: 255, green: 0, blue: 0)
        let fg = solidImage(width: 4, height: 4, red: 0, green: 255, blue: 0)
        let data = try #require(ImageFlattener.flatten(background: bg, foreground: fg))
        let provider = CGDataProvider(data: data as CFData)!
        let output = try #require(CGImage(pngDataProviderSource: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))

        #expect(output.width == 10)
        #expect(output.height == 10)

        // Top-left should be green (foreground)
        let topLeft = pixel(in: output, x: 1, y: 1)
        #expect(topLeft.g == 255)

        // Bottom-right should be red (background, outside foreground bounds)
        let bottomRight = pixel(in: output, x: 9, y: 9)
        #expect(bottomRight.r == 255)
        #expect(bottomRight.g == 0)
    }

    @Test("foreground larger than background — output still matches background size")
    func foregroundLargerThanBackground() throws {
        let bg = solidImage(width: 4, height: 4, red: 255, green: 0, blue: 0)
        let fg = solidImage(width: 10, height: 10, red: 0, green: 255, blue: 0)
        let data = try #require(ImageFlattener.flatten(background: bg, foreground: fg))
        let provider = CGDataProvider(data: data as CFData)!
        let output = try #require(CGImage(pngDataProviderSource: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))

        #expect(output.width == 4)
        #expect(output.height == 4)
    }

    @Test("1×1 minimum size produces valid output")
    func minimumSizeProducesOutput() {
        // The zero-size guard in flatten is defense-in-depth — CGImage itself
        // prevents zero dimensions. Verify the smallest valid input works.
        let bg = solidImage(width: 1, height: 1, red: 255, green: 0, blue: 0)
        let fg = solidImage(width: 1, height: 1, red: 0, green: 0, blue: 0)
        let data = ImageFlattener.flatten(background: bg, foreground: fg)
        #expect(data != nil)
    }
}
