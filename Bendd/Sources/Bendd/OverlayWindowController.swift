import AppKit
import MetalKit
import BenddKit

final class OverlayWindowController {
    let window: NSWindow
    let metalView: MTKView
    private let renderer: BendRenderer

    init(screen: NSScreen, device: MTLDevice, renderer: BendRenderer) {
        self.renderer = renderer
        let view = MTKView(frame: screen.frame, device: device)
        view.delegate = renderer
        view.colorPixelFormat = .bgra8Unorm
        view.clearColor = MTLClearColorMake(0, 0, 0, 0)
        view.isPaused = false
        view.enableSetNeedsDisplay = false
        view.layer?.isOpaque = false
        (view.layer as? CAMetalLayer)?.isOpaque = false
        self.metalView = view

        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false,
            screen: screen
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.contentView = view
        self.window = window
    }

    func show() {
        window.orderFrontRegardless()
    }
}
