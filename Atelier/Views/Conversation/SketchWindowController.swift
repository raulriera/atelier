import AppKit

/// Pure AppKit sketch window.
///
/// Opens a standalone `NSWindow` with PaperKit's markup canvas and toolbar.
/// On Done, renders the markup to PNG and calls the completion closure.
final class SketchWindowController: NSWindowController {

    private var completion: ((Data) -> Void)?

    /// Retains the active controller until the window closes.
    private static var activeController: SketchWindowController?

    /// Opens a sketch window. The completion closure receives PNG data on Done.
    ///
    /// - Parameters:
    ///   - backgroundImage: An optional image displayed behind the markup canvas.
    ///     When provided, the image is shown as a non-interactive background and
    ///     composited into the final PNG render.
    ///   - completion: A closure called with the rendered PNG data when the user
    ///     taps Done. Not called if the user cancels.
    @MainActor
    static func open(backgroundImage: NSImage? = nil, completion: ((Data) -> Void)? = nil) {
        // Prevent concurrent sketch windows.
        guard activeController == nil else { return }

        let sketchVC = SketchViewController()
        sketchVC.backgroundImage = backgroundImage
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Sketch"
        window.contentViewController = sketchVC
        window.center()

        let controller = SketchWindowController(window: window)
        window.delegate = controller
        controller.completion = completion
        sketchVC.onDone = { [weak controller] data in
            controller?.completion?(data)
            controller?.close()
        }
        sketchVC.onCancel = { [weak controller] in
            controller?.close()
        }

        activeController = controller
        controller.showWindow(nil)
    }

}

extension SketchWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        Self.activeController = nil
    }
}
