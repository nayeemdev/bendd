import Metal

/// Coordinates the sensor, desktop capture, and renderer: starts capture only
/// while the lid is closed enough to need the bend effect, and stops it once
/// the lid clears back past the threshold, so idle cost stays at zero.
///
/// Never throws or crashes on missing hardware or a denied permission: when
/// the lid angle sensor isn't found, or a capture attempt fails, the app
/// degrades to doing nothing rather than taking down the whole process.
public final class BendController {
    public let sensor: LidAngleSensor?
    public let capture: DesktopCapture
    public let renderer: BendRenderer

    public let isSensorAvailable: Bool

    /// Called whenever the effect should become visible or hide, on the main thread.
    public var onActiveChange: ((Bool) -> Void)?
    /// Called whenever a capture attempt fails, e.g. Screen Recording permission denied.
    public var onCaptureError: ((Error) -> Void)?
    /// Called when the lid crosses back past the clear angle while open, so a
    /// chime can play. Not fired just because the user toggled the effect off.
    public var onLidFullyOpened: (() -> Void)?

    public var configuration: BendConfiguration = .default {
        didSet {
            renderer.configuration = configuration
            handle(angle: sensor?.effectiveAngleDegrees ?? configuration.clearAngleDegrees)
        }
    }

    private var isActive = false
    private var isAngleClear = true

    public init(device: MTLDevice) throws {
        let sensor = LidAngleSensor.make()
        self.sensor = sensor
        self.isSensorAvailable = sensor != nil
        self.capture = DesktopCapture(device: device)
        self.renderer = try BendRenderer(device: device)

        renderer.textureProvider = { [capture] in capture.currentTexture() }
        renderer.lidAngleDegreesProvider = { [sensor] in sensor?.effectiveAngleDegrees ?? BendConfiguration.default.clearAngleDegrees }
        renderer.configuration = configuration

        sensor?.onAngleChange = { [weak self] angle in self?.handle(angle: angle) }
    }

    public func start() {
        sensor?.start()
    }

    private func handle(angle: Double) {
        let isClear = BendTransform.isClear(lidAngleDegrees: angle, clearAngleDegrees: configuration.clearAngleDegrees)
        if isClear, !isAngleClear, configuration.isSoundEnabled {
            onLidFullyOpened?()
        }
        isAngleClear = isClear

        let shouldBeActive = configuration.isEffectEnabled && !isClear
        guard shouldBeActive != isActive else { return }
        isActive = shouldBeActive
        sensor?.setTrackingActive(shouldBeActive)
        onActiveChange?(shouldBeActive)

        if shouldBeActive {
            Task { [weak self, capture] in
                do {
                    let display = try await DesktopCapture.builtInDisplay()
                    try await capture.start(display: display)
                } catch {
                    self?.onCaptureError?(error)
                }
            }
        } else {
            Task { [capture] in await capture.stop() }
        }
    }
}
