import AppKit
import CoreGraphics

// Renders Bendd's app icon at every size macOS expects, into an .iconset
// folder ready for `iconutil`. Run via `swift generate-icon.swift <outputDir>`.

func drawIcon(size: CGFloat) -> NSImage {
    NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
        guard let context = NSGraphicsContext.current?.cgContext else { return false }

        let backgroundPath = CGPath(roundedRect: rect, cornerWidth: size * 0.22, cornerHeight: size * 0.22, transform: nil)
        context.addPath(backgroundPath)
        context.clip()

        let colors = [NSColor.systemBlue.cgColor, NSColor.systemPurple.cgColor, NSColor.systemPink.cgColor]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0, 0.5, 1]) {
            context.drawLinearGradient(
                gradient,
                start: CGPoint(x: rect.minX, y: rect.maxY),
                end: CGPoint(x: rect.maxX, y: rect.minY),
                options: []
            )
        }

        NSColor.white.setFill()
        NSColor.white.setStroke()

        let baseHeight = size * 0.09
        let base = NSBezierPath(
            roundedRect: NSRect(x: size * 0.16, y: size * 0.18, width: size * 0.68, height: baseHeight),
            xRadius: baseHeight / 2,
            yRadius: baseHeight / 2
        )
        base.fill()

        context.saveGState()
        let hinge = CGPoint(x: size * 0.5, y: size * 0.30)
        context.translateBy(x: hinge.x, y: hinge.y)
        context.rotate(by: -16 * .pi / 180)
        context.translateBy(x: -hinge.x, y: -hinge.y)

        let screen = NSBezierPath(
            roundedRect: NSRect(x: size * 0.22, y: size * 0.30, width: size * 0.56, height: size * 0.46),
            xRadius: size * 0.06,
            yRadius: size * 0.06
        )
        screen.lineWidth = size * 0.055
        screen.stroke()

        context.restoreGState()
        return true
    }
}

func pngData(from image: NSImage, size: CGFloat) -> Data? {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size),
        pixelsHigh: Int(size),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let outputDir = CommandLine.arguments[1]
let sizes: [(name: String, points: CGFloat, scale: CGFloat)] = [
    ("icon_16x16", 16, 1), ("icon_16x16@2x", 16, 2),
    ("icon_32x32", 32, 1), ("icon_32x32@2x", 32, 2),
    ("icon_128x128", 128, 1), ("icon_128x128@2x", 128, 2),
    ("icon_256x256", 256, 1), ("icon_256x256@2x", 256, 2),
    ("icon_512x512", 512, 1), ("icon_512x512@2x", 512, 2),
]

try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)

for entry in sizes {
    let pixelSize = entry.points * entry.scale
    let image = drawIcon(size: pixelSize)
    guard let data = pngData(from: image, size: pixelSize) else { continue }
    let path = "\(outputDir)/\(entry.name).png"
    try? data.write(to: URL(fileURLWithPath: path))
    print("wrote \(path)")
}
