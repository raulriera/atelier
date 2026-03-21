import AppKit
import PaperKit

/// Hosts `PaperMarkupViewController` and `MarkupToolbarViewController`
/// following Apple's PaperKit AppKit guide.
final class SketchViewController: NSViewController {
    @ViewLoading private var paperViewController: PaperMarkupViewController
    @ViewLoading private var markupToolbarViewController: MarkupToolbarViewController
    @ViewLoading private var paperMarkup: PaperMarkup

    /// Optional background image displayed behind all markup and drawing.
    var backgroundImage: NSImage?

    var onDone: ((Data) -> Void)?
    var onCancel: (() -> Void)?

    /// Fixed canvas size — PaperMarkupViewController scrolls within the window.
    private static let canvasSize = NSSize(width: 1024, height: 768)

    override func loadView() {
        view = NSView(frame: NSRect(origin: .zero, size: Self.canvasSize))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        paperMarkup = PaperMarkup(bounds: CGRect(origin: .zero, size: Self.canvasSize))

        paperViewController = PaperMarkupViewController(
            markup: paperMarkup,
            supportedFeatureSet: .latest
        )
        paperViewController.isEditable = true
        paperViewController.indirectPointerTouchMode = .drawing

        view.addSubview(paperViewController.view)
        addChild(paperViewController)
        setupLayoutConstraints()
        setupToolbarViewController()
        setupDoneCancel()

        if backgroundImage != nil {
            loadBackgroundImage()
        }
    }

    private func setupLayoutConstraints() {
        paperViewController.view.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            paperViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            paperViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            paperViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            paperViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func setupToolbarViewController() {
        markupToolbarViewController = MarkupToolbarViewController(supportedFeatureSet: .latest)
        markupToolbarViewController.delegate = paperViewController

        let toolbarView = markupToolbarViewController.view
        toolbarView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbarView)
        addChild(markupToolbarViewController)

        NSLayoutConstraint.activate([
            toolbarView.topAnchor.constraint(equalTo: view.topAnchor),
            toolbarView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    private func setupDoneCancel() {
        let done = NSButton(title: "Done", target: self, action: #selector(donePressed))
        done.bezelStyle = .rounded
        done.keyEquivalent = "\r"
        done.translatesAutoresizingMaskIntoConstraints = false

        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancelPressed))
        cancel.bezelStyle = .rounded
        cancel.keyEquivalent = "\u{1b}"
        cancel.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(cancel)
        view.addSubview(done)

        NSLayoutConstraint.activate([
            done.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            done.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),

            cancel.trailingAnchor.constraint(equalTo: done.leadingAnchor, constant: -8),
            cancel.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
        ])
    }

    @objc private func donePressed() {
        Task { @MainActor in
            if let data = await renderToPNG() {
                onDone?(data)
            } else {
                onCancel?()
            }
        }
    }

    @objc private func cancelPressed() {
        onCancel?()
    }

    // MARK: - Background Image

    /// Sets the background image as the markup controller's content view,
    /// rendering it behind all markup and drawing.
    private func loadBackgroundImage() {
        guard let backgroundImage else { return }
        let imageView = NSImageView(image: backgroundImage)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        paperViewController.contentView = imageView
    }

    // MARK: - Rendering

    private func renderToPNG() async -> Data? {
        guard let markup = paperViewController.markup else { return nil }

        let bounds = markup.bounds
        let scale = NSScreen.main?.backingScaleFactor ?? 2.0
        let pixelWidth = Int(bounds.width * scale)
        let pixelHeight = Int(bounds.height * scale)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let cgContext = CGContext(
                  data: nil,
                  width: pixelWidth,
                  height: pixelHeight,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }

        // PaperKit's markup.draw() renders strokes only — it does not include
        // the contentView. Draw the background image explicitly before the
        // coordinate flip. CGContext.draw handles orientation in bottom-left coords.
        if let backgroundImage,
           let bgCGImage = backgroundImage.cgImage(
               forProposedRect: nil, context: nil, hints: nil
           ) {
            // Aspect-fit to match the live NSImageView (.scaleProportionallyUpOrDown).
            let imageAspect = CGFloat(bgCGImage.width) / CGFloat(bgCGImage.height)
            let canvasAspect = CGFloat(pixelWidth) / CGFloat(pixelHeight)
            let bgRect: CGRect
            if imageAspect > canvasAspect {
                let h = CGFloat(pixelWidth) / imageAspect
                bgRect = CGRect(x: 0, y: (CGFloat(pixelHeight) - h) / 2, width: CGFloat(pixelWidth), height: h)
            } else {
                let w = CGFloat(pixelHeight) * imageAspect
                bgRect = CGRect(x: (CGFloat(pixelWidth) - w) / 2, y: 0, width: w, height: CGFloat(pixelHeight))
            }
            cgContext.draw(bgCGImage, in: bgRect)
        }

        // Flip to top-left origin for consistent coordinate system.
        cgContext.translateBy(x: 0, y: CGFloat(pixelHeight))
        cgContext.scaleBy(x: scale, y: -scale)

        let options = RenderingOptions(
            darkUserInterfaceStyle: NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua,
            layoutRightToLeft: NSApp.userInterfaceLayoutDirection == .rightToLeft
        )
        await markup.draw(in: cgContext, frame: bounds, options: options)

        guard let cgImage = cgContext.makeImage() else { return nil }

        // Direct CGImage → PNG, no TIFF round-trip.
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        return bitmap.representation(using: .png, properties: [:])
    }
}
