import AppKit

/// A small custom glyph: a laptop base with its screen tilted forward, so the
/// icon itself hints at what the app does. Drawn as a template image so
/// AppKit tints it correctly for the light and dark menu bar.
enum MenuBarIcon {
    static func make() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            let color = NSColor.black
            color.setFill()
            color.setStroke()

            // Base / keyboard deck.
            let base = NSBezierPath(roundedRect: NSRect(x: 1.5, y: 1.5, width: 15, height: 3), xRadius: 1, yRadius: 1)
            base.fill()

            // Screen, tilted forward around its bottom edge to read as "bending".
            context.saveGState()
            let hinge = CGPoint(x: 9, y: 5.2)
            context.translateBy(x: hinge.x, y: hinge.y)
            context.rotate(by: -18 * .pi / 180)
            context.translateBy(x: -hinge.x, y: -hinge.y)

            let screen = NSBezierPath(roundedRect: NSRect(x: 3, y: 5, width: 12, height: 9), xRadius: 1.2, yRadius: 1.2)
            screen.lineWidth = 1.4
            screen.stroke()

            context.restoreGState()
            return true
        }
        image.isTemplate = true
        return image
    }
}
