import Metal

public final class BendController {
    public let sensor: LidAngleSensor?
    public let capture: DesktopCapture
    public let renderer: BendRenderer

    public let isSensorAvailable: Bool

    public var onActiveChange: ((Bool) -> Void)?
    public var onCaptureError: ((Error) -> Void)?
    public var onCaptureRecovered: (() -> Void)?
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
                    self?.onCaptureRecovered?()
                } catch {
                    self?.onCaptureError?(error)
                }
            }
        } else {
            Task { [capture] in await capture.stop() }
        }
    }
}
