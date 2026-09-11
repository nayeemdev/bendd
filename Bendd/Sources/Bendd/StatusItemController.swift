import AppKit
import SwiftUI

final class StatusItemController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private let store: SettingsStore
    private let currentAngleProvider: () -> Double

    init(store: SettingsStore, currentAngleProvider: @escaping () -> Double) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()
        self.store = store
        self.currentAngleProvider = currentAngleProvider

        super.init()

        if let button = statusItem.button {
            button.image = MenuBarIcon.make()
            button.image?.accessibilityDescription = "Bendd"
            button.action = #selector(handleClick)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover.behavior = .transient
        popover.delegate = self
    }

    @objc private func handleClick() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            store.configuration.isEffectEnabled.toggle()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            show(relativeTo: button)
        }
    }

    func simulateClick() {
        statusItem.button?.performClick(nil)
    }

    private func show(relativeTo button: NSStatusBarButton) {
        // Rebuilt on every show and torn down in popoverDidClose, so the
        // preview's animation timer doesn't keep running while hidden.
        let hostingController = NSHostingController(
            rootView: SettingsView(store: store, currentAngleProvider: currentAngleProvider)
        )
        // Without this, the popover can present before SwiftUI's ideal size
        // is known and clip the top of the content instead of sizing to fit.
        hostingController.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hostingController
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    func popoverDidClose(_ notification: Notification) {
        popover.contentViewController = nil
    }
}
