import AppKit
import Combine
import BenddKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let device: MTLDevice
    private let controller: BendController
    private let store = SettingsStore()
    private var overlay: OverlayWindowController?
    private var statusItemController: StatusItemController?
    private var cancellables: Set<AnyCancellable> = []

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

        let overlay = OverlayWindowController(screen: builtInScreen, device: device, renderer: controller.renderer)
        self.overlay = overlay

        controller.onActiveChange = { [overlay] isActive in
            overlay.setActive(isActive)
        }

        controller.configuration = store.configuration
        if LaunchAtLogin.isRegistered != store.configuration.launchAtLogin {
            store.configuration.launchAtLogin = LaunchAtLogin.isRegistered
        }

        store.$configuration
            .sink { [controller] configuration in controller.configuration = configuration }
            .store(in: &cancellables)

        // Seed from any debug override already on the sensor (e.g. BENDD_DEBUG_ANGLE)
        // so subscribing below doesn't immediately clobber it back to nil.
        store.previewAngleOverride = controller.sensor.debugAngleOverride

        store.$previewAngleOverride
            .sink { [controller] override in controller.sensor.debugAngleOverride = override }
            .store(in: &cancellables)

        let statusItemController = StatusItemController(store: store) { [controller] in
            controller.sensor.effectiveAngleDegrees
        }
        self.statusItemController = statusItemController

        controller.start()

        if ProcessInfo.processInfo.environment["BENDD_DEBUG_SHOW_POPOVER"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSApp.activate(ignoringOtherApps: true)
                statusItemController.show()
            }
        }
    }

    // A menu-bar-only app has no main window to speak of; closing the overlay
    // or the settings popover must never quit it. Only the Quit button in
    // the settings popover, or the Dock/Activity Monitor, should terminate it.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
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
