import AppKit
import SwiftUI

final class OnboardingWindowController: NSWindowController {
    private static let defaultsKey = "com.bendd.hasCompletedOnboarding"

    static var hasCompletedOnboarding: Bool {
        UserDefaults.standard.bool(forKey: defaultsKey)
    }

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Bendd"
        window.center()
        window.isReleasedWhenClosed = false
        self.init(window: window)

        window.contentView = NSHostingView(rootView: OnboardingView { [weak self] in
            self?.finish()
        })
    }

    func showIfNeeded() {
        guard !Self.hasCompletedOnboarding else { return }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: Self.defaultsKey)
        close()
    }
}
