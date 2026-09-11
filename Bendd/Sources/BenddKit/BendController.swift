import Metal

public enum BendControllerError: Error, CustomStringConvertible {
    case noSensorFound

    public var description: String {
        switch self {
        case .noSensorFound: "No lid angle sensor found on this Mac."
        }
    }
}

/// Coordinates the sensor, desktop capture, and renderer: starts capture only
/// while the lid is closed enough to need the bend effect, and stops it once
/// the lid clears back past the threshold, so idle cost stays at zero.
public final class BendController {
    public let sensor: LidAngleSensor
    public let capture: DesktopCapture
    public let renderer: BendRenderer

    /// Called whenever the effect should become visible or hide, on the main thread.
    public var onActiveChange: ((Bool) -> Void)?

    public var configuration: BendConfiguration = .default {
        didSet {
            renderer.configuration = configuration
            handle(angle: sensor.effectiveAngleDegrees)
        }
    }

    private var isActive = false

    public init(device: MTLDevice) throws {
        guard let sensor = LidAngleSensor.make() else {
            throw BendControllerError.noSensorFound
        }
        self.sensor = sensor
        self.capture = DesktopCapture(device: device)
        self.renderer = try BendRenderer(device: device)

        renderer.textureProvider = { [capture] in capture.currentTexture() }
        renderer.lidAngleDegreesProvider = { [sensor] in sensor.effectiveAngleDegrees }
        renderer.configuration = configuration

        sensor.onAngleChange = { [weak self] angle in self?.handle(angle: angle) }
    }

    public func start() {
        sensor.start()
    }

    private func handle(angle: Double) {
        let shouldBeActive = configuration.isEffectEnabled && !BendTransform.isClear(lidAngleDegrees: angle, clearAngleDegrees: configuration.clearAngleDegrees)
        guard shouldBeActive != isActive else { return }
        isActive = shouldBeActive
        sensor.setTrackingActive(shouldBeActive)
        onActiveChange?(shouldBeActive)

        if shouldBeActive {
            Task { [capture] in
                do {
                    let display = try await DesktopCapture.builtInDisplay()
                    try await capture.start(display: display)
                } catch {
                    print("desktop capture failed to start: \(error)")
                }
            }
        } else {
            Task { [capture] in await capture.stop() }
        }
    }
}
