import Foundation
import CoreGraphics
import ScreenCaptureKit
import Metal

public enum DesktopCaptureError: Error, CustomStringConvertible {
    case noDisplayFound
    case screenRecordingDenied

    public var description: String {
        switch self {
        case .noDisplayFound:
            "No display found to capture."
        case .screenRecordingDenied:
            "Screen Recording permission was denied."
        }
    }
}

public final class DesktopCapture: NSObject {
    private let device: MTLDevice
    private let outputQueue = DispatchQueue(label: "com.bendd.capture.output")
    private let textureLock = NSLock()
    private var stream: SCStream?
    private var latestTexture: MTLTexture?

    public init(device: MTLDevice) {
        self.device = device
    }

    public func currentTexture() -> MTLTexture? {
        textureLock.withLock { latestTexture }
    }

    // Excludes Bendd's own process, not just its window: SCShareableContent's
    // window list doesn't reliably surface a .screenSaver-level window, so
    // filtering by window ID silently fails and re-captures the bent overlay.
    public func start() async throws {
        guard CGPreflightScreenCaptureAccess() || CGRequestScreenCaptureAccess() else {
            throw DesktopCaptureError.screenRecordingDenied
        }

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let display = content.displays.first(where: { CGDisplayIsBuiltin($0.displayID) != 0 }) ?? content.displays.first else {
            throw DesktopCaptureError.noDisplayFound
        }

        let ownProcessID = ProcessInfo.processInfo.processIdentifier
        let excludedApplications = content.applications.filter { $0.processID == ownProcessID }

        let filter = SCContentFilter(display: display, excludingApplications: excludedApplications, exceptingWindows: [])
        let configuration = SCStreamConfiguration()
        configuration.width = display.width * 2
        configuration.height = display.height * 2
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.showsCursor = false
        configuration.queueDepth = 3

        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: outputQueue)
        try await stream.startCapture()
        self.stream = stream
    }

    public func stop() async {
        guard let stream else { return }
        try? await stream.stopCapture()
        self.stream = nil
    }
}

extension DesktopCapture: SCStreamOutput {
    public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, sampleBuffer.isValid,
              let pixelBuffer = sampleBuffer.imageBuffer,
              let surface = CVPixelBufferGetIOSurface(pixelBuffer)?.takeUnretainedValue()
        else { return }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.shaderRead]

        guard let texture = device.makeTexture(descriptor: descriptor, iosurface: surface, plane: 0) else {
            print("capture: makeTexture failed for \(width)x\(height)")
            return
        }

        textureLock.withLock { latestTexture = texture }
    }
}

extension DesktopCapture: SCStreamDelegate {
    public func stream(_ stream: SCStream, didStopWithError error: Error) {
        textureLock.withLock { latestTexture = nil }
    }
}
