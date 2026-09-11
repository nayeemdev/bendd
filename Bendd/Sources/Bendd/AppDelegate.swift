import AppKit
import BenddKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let device: MTLDevice
    private let sensor: LidAngleSensor
    private let capture: DesktopCapture
    private var overlay: OverlayWindowController?

    override init() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("This Mac has no Metal device.")
        }
        guard let sensor = LidAngleSensor.make() else {
            fatalError("No lid angle sensor found on this Mac.")
        }
        self.device = device
        self.sensor = sensor
        self.capture = DesktopCapture(device: device)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let builtInScreen = NSScreen.builtIn ?? NSScreen.main else {
            fatalError("No screen available to render the bend overlay on.")
        }

        let renderer: BendRenderer
        do {
            renderer = try BendRenderer(device: device)
        } catch {
            fatalError("Renderer setup failed: \(error)")
        }
        renderer.lidAngleDegreesProvider = { [sensor] in
            if let raw = ProcessInfo.processInfo.environment["BENDD_DEBUG_ANGLE"], let override = Double(raw) {
                return override
            }
            return sensor.angleDegrees
        }
        renderer.textureProvider = { [capture] in capture.currentTexture() }

        let overlay = OverlayWindowController(screen: builtInScreen, device: device, renderer: renderer)
        overlay.show()
        self.overlay = overlay

        sensor.start()

        Task {
            do {
                let display = try await DesktopCapture.builtInDisplay()
                try await capture.start(display: display)
            } catch {
                print("desktop capture failed to start: \(error)")
            }
        }
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
