import Foundation
import ScreenCaptureKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum CaptureError: Error, CustomStringConvertible {
    case screenRecordingDenied
    case noDisplayFound
    case pngEncodingFailed

    var description: String {
        switch self {
        case .screenRecordingDenied:
            "Screen Recording permission was denied. Grant it in System Settings > Privacy & Security > Screen Recording, then run again."
        case .noDisplayFound:
            "No display found."
        case .pngEncodingFailed:
            "Could not encode the captured image as PNG."
        }
    }
}

func requestScreenRecordingAccess() throws {
    guard !CGPreflightScreenCaptureAccess() else { return }
    guard CGRequestScreenCaptureAccess() else { throw CaptureError.screenRecordingDenied }
}

func captureDesktop() async throws -> CGImage {
    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
    guard let display = content.displays.first else { throw CaptureError.noDisplayFound }

    let filter = SCContentFilter(display: display, excludingWindows: [])
    let config = SCStreamConfiguration()
    config.width = display.width * 2
    config.height = display.height * 2
    config.showsCursor = false

    return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw CaptureError.pngEncodingFailed
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { throw CaptureError.pngEncodingFailed }
}

setvbuf(stdout, nil, _IONBF, 0)

let outputURL = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "desktop.png")

do {
    try requestScreenRecordingAccess()
    let image = try await captureDesktop()
    try writePNG(image, to: outputURL)
    print("captured desktop at \(image.width)x\(image.height), saved to \(outputURL.path)")
} catch {
    print(error)
    exit(1)
}
