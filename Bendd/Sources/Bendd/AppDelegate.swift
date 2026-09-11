import AppKit
import BenddKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let device: MTLDevice
    private let controller: BendController
    private var overlay: OverlayWindowController?

    override init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("This Mac has no Metal device.")
        }
        self.device = device
        do {
            self.controller = try BendController(device: device)
        } catch {
            fatalError("\(error)")
        }
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let builtInScreen = NSScreen.builtIn ?? NSScreen.main else {
            fatalError("No screen available to render the bend overlay on.")
        }

        if let raw = ProcessInfo.processInfo.environment["BENDD_DEBUG_STYLE"], let style = BendStyle(rawValue: raw) {
            controller.renderer.style = style
        }

        let overlay = OverlayWindowController(screen: builtInScreen, device: device, renderer: controller.renderer)
        overlay.show()
        self.overlay = overlay

        controller.onActiveChange = { [overlay] isActive in
            overlay.metalView.isPaused = !isActive
        }
        overlay.metalView.isPaused = true

        controller.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

private extension NSScreen {
    static var builtIn: NSScreen? {
        screens.first { screen in
            guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                return false
            }
            return CGDisplayIsBuiltin(screenNumber) != 0
        }
    }
}
