import AppKit
import MetalKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let textureURL: URL
    private var window: NSWindow?
    private var renderer: Renderer?

    init(textureURL: URL) {
        self.textureURL = textureURL
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("This Mac has no Metal device.")
        }

        let mtkView = MTKView(frame: NSRect(x: 0, y: 0, width: 1280, height: 800), device: device)
        mtkView.colorPixelFormat = .bgra8Unorm

        do {
            let renderer = try Renderer(device: device, textureURL: textureURL)
            mtkView.delegate = renderer
            self.renderer = renderer
        } catch {
            fatalError("Renderer setup failed: \(error)")
        }

        let window = NSWindow(
            contentRect: mtkView.frame,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Bendd, Metal perspective spike"
        window.contentView = mtkView
        window.makeKeyAndOrderFront(nil)
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
